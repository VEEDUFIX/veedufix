import { createHmac } from "crypto";
import Razorpay from "razorpay";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { logger } from "../../lib/logger.js";
import { sendMulticastPush } from "../../lib/fcm.js";
import { env } from "../../config/env.js";

// ── Types ────────────────────────────────────────────────────────────────────

export interface SparePartItem {
  label: string;
  amount: number;
}

// ── Razorpay client ───────────────────────────────────────────────────────────

function getRazorpayClient(): Razorpay {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new AppError(500, "Razorpay credentials are not configured");
  }
  return new Razorpay({ key_id: env.RAZORPAY_KEY_ID, key_secret: env.RAZORPAY_KEY_SECRET });
}

// ── Worker: Submit spare parts request ───────────────────────────────────────

export async function submitSpareParts(
  workerId: string,
  bookingId: string,
  items: SparePartItem[],
  receiptPhotoUrl?: string
): Promise<void> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { worker: true, sparePartRequest: true }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.worker?.userId !== workerId) throw AppError.forbidden("You are not assigned to this booking");
  if (booking.sparePartRequest) throw AppError.conflict("A spare parts request already exists for this booking");

  const totalAmount = items.reduce((sum, i) => sum + i.amount, 0);

  await prisma.sparePartRequest.create({
    data: {
      bookingId,
      workerId,
      items,
      receiptPhotoUrl: receiptPhotoUrl ?? null,
      totalAmount,
      status: "PENDING"
    }
  });

  // Push notification to customer
  try {
    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId: booking.customerId },
      select: { token: true }
    });
    const tokens = deviceTokens.map((d) => d.token);
    if (tokens.length > 0) {
      await sendMulticastPush({
        tokens,
        title: "Spare Parts Added 🔧",
        body: `The professional has added spare parts for ₹${totalAmount.toLocaleString("en-IN")}. Please review and pay to proceed.`,
        data: { type: "SPARE_PARTS_PENDING", bookingId }
      });
    }
  } catch (err) {
    logger.warn({ err, bookingId }, "submitSpareParts: push notification failed");
  }

  logger.info({ bookingId, workerId, totalAmount }, "Spare parts request submitted");
}

// ── Customer: Create Razorpay order to pay for spare parts ───────────────────

export async function createSparePartsPaymentOrder(
  customerId: string,
  bookingId: string
): Promise<{
  keyId: string;
  orderId: string;
  amountPaise: number;
  currency: string;
  customerName: string;
  customerPhone: string | null;
}> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { customer: true, sparePartRequest: true }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");

  const spareReq = booking.sparePartRequest;
  if (!spareReq) throw AppError.notFound("No spare parts request found for this booking");
  if (spareReq.status !== "PENDING") throw AppError.conflict("Spare parts request is no longer pending");

  const amountPaise = Math.round(Number(spareReq.totalAmount) * 100);
  if (amountPaise < 100) throw AppError.badRequest("Amount is below minimum payable amount");

  const razorpay = getRazorpayClient();
  const ordersClient = razorpay.orders as unknown as {
    create: (opts: Record<string, unknown>) => Promise<{ id: string }>;
  };

  const rzpOrder = await ordersClient.create({
    amount: amountPaise,
    currency: "INR",
    receipt: `spare_${bookingId.slice(0, 20)}`,
    notes: { bookingId, type: "spare_parts" }
  });

  await prisma.sparePartRequest.update({
    where: { bookingId },
    data: { razorpayOrderId: rzpOrder.id }
  });

  logger.info({ bookingId, customerId, amountPaise }, "Spare parts Razorpay order created");
  return {
    keyId: env.RAZORPAY_KEY_ID!,
    orderId: rzpOrder.id,
    amountPaise,
    currency: "INR",
    customerName: booking.customer.name,
    customerPhone: booking.customer.phone ?? null
  };
}

// ── Customer: Verify Razorpay payment for spare parts ────────────────────────

export async function verifySparePartsPayment(
  customerId: string,
  bookingId: string,
  razorpayOrderId: string,
  razorpayPaymentId: string,
  razorpaySignature: string
): Promise<void> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { worker: true, sparePartRequest: true }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");

  const spareReq = booking.sparePartRequest;
  if (!spareReq) throw AppError.notFound("No spare parts request found");
  if (spareReq.status !== "PENDING") throw AppError.conflict("Spare parts already processed");

  // Verify signature
  if (!env.RAZORPAY_KEY_SECRET) throw new AppError(500, "Razorpay credentials not configured");
  const expected = createHmac("sha256", env.RAZORPAY_KEY_SECRET)
    .update(`${razorpayOrderId}|${razorpayPaymentId}`)
    .digest("hex");

  if (expected !== razorpaySignature) throw AppError.badRequest("Invalid payment signature");

  // Mark spare parts as PAID and update booking total
  const spareAmount = Number(spareReq.totalAmount);
  const newTotal = Number(booking.totalAmount) + spareAmount;

  await prisma.$transaction([
    prisma.sparePartRequest.update({
      where: { bookingId },
      data: { status: "PAID", razorpayPaymentId }
    }),
    prisma.booking.update({
      where: { id: bookingId },
      data: { totalAmount: newTotal }
    })
  ]);

  // Notify worker
  try {
    if (booking.worker) {
      const deviceTokens = await prisma.deviceToken.findMany({
        where: { userId: booking.worker.userId },
        select: { token: true }
      });
      const tokens = deviceTokens.map((d) => d.token);
      if (tokens.length > 0) {
        await sendMulticastPush({
          tokens,
          title: "Spare Parts Paid ✅",
          body: "Customer has paid for the spare parts. You can proceed with the installation.",
          data: { type: "SPARE_PARTS_PAID", bookingId }
        });
      }
    }
  } catch (err) {
    logger.warn({ err, bookingId }, "verifySparePartsPayment: push notification failed");
  }

  logger.info({ bookingId, customerId, razorpayPaymentId }, "Spare parts payment verified");
}

// ── Customer: Reject spare parts request ─────────────────────────────────────

export async function rejectSpareParts(
  customerId: string,
  bookingId: string
): Promise<void> {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: { sparePartRequest: true }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");
  if (booking.sparePartRequest?.status !== "PENDING") throw AppError.conflict("No pending spare parts request");

  await prisma.sparePartRequest.update({
    where: { bookingId },
    data: { status: "REJECTED" }
  });

  logger.info({ bookingId, customerId }, "Spare parts request rejected");
}
