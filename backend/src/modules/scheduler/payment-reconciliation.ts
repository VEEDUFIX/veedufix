import cron from "node-cron";
import Razorpay from "razorpay";
import { PaymentStatus } from "@prisma/client";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { updatePaymentForWebhook } from "../webhooks/webhooks.service.js";

type RazorpayOrderRecord = {
  id: string;
  amount?: number;
  currency?: string;
  status?: string;
};

let paymentReconciliationStarted = false;

function createRazorpayClient(): Razorpay | null {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    return null;
  }

  return new Razorpay({
    key_id: env.RAZORPAY_KEY_ID,
    key_secret: env.RAZORPAY_KEY_SECRET
  });
}

function getRazorpayOrderClient(razorpay: Razorpay): {
  fetch(orderId: string): Promise<RazorpayOrderRecord>;
} {
  return (razorpay.orders as unknown) as {
    fetch(orderId: string): Promise<RazorpayOrderRecord>;
  };
}

async function reconcilePaymentOrder(razorpay: Razorpay, orderId: string): Promise<boolean> {
  const orderClient = getRazorpayOrderClient(razorpay);
  const order = await orderClient.fetch(orderId);

  if (order.status !== "paid") {
    return false;
  }

  await updatePaymentForWebhook(
    orderId,
    PaymentStatus.CAPTURED,
    {
      webhookEvent: "reconciled.order.paid",
      reconciledBy: "scheduler",
      paymentStatus: order.status
    },
    order.amount
  );

  return true;
}

export async function reconcileStalePayments(): Promise<{ checked: number; reconciled: number }> {
  const razorpay = createRazorpayClient();
  if (!razorpay) {
    logger.warn("Skipping payment reconciliation because Razorpay credentials are missing");
    return { checked: 0, reconciled: 0 };
  }

  const cutoff = new Date(Date.now() - 15 * 60 * 1000);
  const pendingPayments = await prisma.payment.findMany({
    where: {
      provider: "RAZORPAY",
      status: PaymentStatus.PENDING,
      providerRef: {
        not: null
      },
      createdAt: {
        lte: cutoff
      }
    },
    select: {
      id: true,
      providerRef: true,
      bookingId: true
    },
    orderBy: {
      createdAt: "asc"
    },
    take: 100
  });

  let reconciled = 0;

  for (const payment of pendingPayments) {
    if (!payment.providerRef) {
      continue;
    }

    try {
      const recovered = await reconcilePaymentOrder(razorpay, payment.providerRef);
      if (recovered) {
        reconciled += 1;
        logger.info(
          {
            paymentId: payment.id,
            bookingId: payment.bookingId,
            orderId: payment.providerRef
          },
          "Reconciled missed Razorpay payment"
        );
      }
    } catch (error) {
      logger.warn(
        {
          error,
          paymentId: payment.id,
          bookingId: payment.bookingId,
          orderId: payment.providerRef
        },
        "Failed to reconcile pending Razorpay payment"
      );
    }
  }

  return {
    checked: pendingPayments.length,
    reconciled
  };
}

export function startPaymentReconciliation(): void {
  if (paymentReconciliationStarted) {
    return;
  }

  paymentReconciliationStarted = true;

  void reconcileStalePayments().catch((error) => {
    logger.error({ error }, "Initial payment reconciliation run failed");
  });

  cron.schedule("*/10 * * * *", () => {
    void reconcileStalePayments().catch((error) => {
      logger.error({ error }, "Payment reconciliation cron run failed");
    });
  });

  logger.info("Payment reconciliation cron started");
}
