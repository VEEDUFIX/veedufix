import { Prisma, PaymentStatus, BookingStatus } from "@prisma/client";
import { createHmac, randomBytes } from "crypto";
import Razorpay from "razorpay";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishTrackingEvent } from "../../lib/realtime.js";
import { dispatchBookingAfterPayment } from "../matching/matching.service.js";

type CreatePaymentOrderInput = {
  userId: string;
  amountPaise: number;
  description: string;
  bookingType?: "instant" | "scheduled";
  scheduledFor?: Date;
};

type VerifyPaymentInput = {
  userId: string;
  bookingId: string;
  razorpayOrderId: string;
  razorpayPaymentId: string;
  razorpaySignature: string;
};

type PaymentOrderResult = {
  keyId: string;
  bookingId: string;
  bookingCode: string;
  orderId: string;
  amountPaise: number;
  currency: string;
  customerName: string;
  customerEmail: string | null;
  customerPhone: string | null;
};

type PaymentVerificationResult = {
  bookingId: string;
  bookingCode: string;
  paymentId: string;
  status: PaymentStatus;
};

const razorpay = createRazorpayClient();

function createRazorpayClient(): Razorpay {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new Error("Razorpay credentials are not configured");
  }

  return new Razorpay({
    key_id: env.RAZORPAY_KEY_ID,
    key_secret: env.RAZORPAY_KEY_SECRET
  });
}

function formatBookingCode(): string {
  const suffix = randomBytes(3).toString("hex").toUpperCase();
  return `BK-${Date.now().toString(36).toUpperCase()}-${suffix}`;
}

async function ensureFallbackCity(): Promise<{ id: string; name: string }> {
  const existing = await prisma.city.findFirst({
    orderBy: { createdAt: "asc" }
  });

  if (existing) {
    return existing;
  }

  return prisma.city.create({
    data: {
      name: "VeeduFix City",
      state: "Default State",
      country: "India",
      slug: "veedufix-city"
    }
  });
}

async function ensureBookingAddress(userId: string, cityId: string): Promise<string> {
  const existing = await prisma.address.findFirst({
    where: { userId },
    orderBy: [{ isDefault: "desc" }, { createdAt: "asc" }]
  });

  if (existing) {
    return existing.id;
  }

  const address = await prisma.address.create({
    data: {
      userId,
      cityId,
      label: "Home",
      line1: "Default address",
      pincode: "000000",
      isDefault: true
    }
  });

  return address.id;
}

async function resolveCustomerContext(userId: string): Promise<{
  user: {
    id: string;
    name: string;
    email: string | null;
    phone: string | null;
  };
  cityId: string;
  addressId: string;
}> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: { city: true }
  });

  if (!user) {
    throw new Error("User not found");
  }

  const city = user.city ?? (await ensureFallbackCity());

  if (!user.cityId) {
    await prisma.user.update({
      where: { id: userId },
      data: { cityId: city.id }
    });
  }

  const addressId = await ensureBookingAddress(userId, city.id);

  return {
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone
    },
    cityId: city.id,
    addressId
  };
}

function toRupees(amountPaise: number): Prisma.Decimal {
  return new Prisma.Decimal(amountPaise).div(100);
}

function verifyRazorpaySignature(input: {
  orderId: string;
  paymentId: string;
  signature: string;
}): boolean {
  if (!env.RAZORPAY_KEY_SECRET) {
    throw new Error("Razorpay credentials are not configured");
  }

  const expected = createHmac("sha256", env.RAZORPAY_KEY_SECRET)
    .update(`${input.orderId}|${input.paymentId}`)
    .digest("hex");

  return expected === input.signature;
}

export async function createPaymentOrder(
  input: CreatePaymentOrderInput
): Promise<PaymentOrderResult> {
  const context = await resolveCustomerContext(input.userId);
  const amount = toRupees(input.amountPaise);
  const bookingCode = formatBookingCode();
  const bookingType = input.bookingType ?? "instant";
  const scheduledFor = bookingType === "scheduled" ? input.scheduledFor : undefined;
  const scheduledAt = bookingType === "scheduled" && scheduledFor ? scheduledFor : new Date(Date.now() + 24 * 60 * 60 * 1000);

  const booking = await prisma.booking.create({
    data: {
      code: bookingCode,
      customerId: context.user.id,
      bookingType,
      ...(scheduledFor ? { scheduledFor } : {}),
      cityId: context.cityId,
      addressId: context.addressId,
      status: BookingStatus.PENDING,
      scheduledAt,
      notes: input.description,
      customerNotes: input.description,
      subtotalAmount: amount,
      discountAmount: 0,
      taxAmount: 0,
      totalAmount: amount
    }
  });

  const order = await razorpay.orders.create({
    amount: input.amountPaise,
    currency: "INR",
    receipt: booking.code,
    notes: {
      bookingId: booking.id,
      bookingCode: booking.code,
      description: input.description
    }
  });

  await prisma.payment.create({
    data: {
      bookingId: booking.id,
      status: PaymentStatus.PENDING,
      provider: "RAZORPAY",
      providerRef: order.id,
      amount,
      currency: "INR",
      notes: {
        description: input.description,
        orderId: order.id
      }
    }
  });

  logger.info({
    bookingId: booking.id,
    bookingCode: booking.code,
    orderId: order.id,
    userId: context.user.id
  }, "Razorpay order created");

  await publishTrackingEvent({
    bookingId: booking.id,
    bookingCode: booking.code,
    status: "PAYMENT_PENDING",
    message: "Payment order created",
    actorRole: "CUSTOMER"
  });

  return {
    keyId: env.RAZORPAY_KEY_ID ?? "",
    bookingId: booking.id,
    bookingCode: booking.code,
    orderId: order.id,
    amountPaise: input.amountPaise,
    currency: "INR",
    customerName: context.user.name,
    customerEmail: context.user.email,
    customerPhone: context.user.phone
  };
}

export async function verifyPayment(
  input: VerifyPaymentInput
): Promise<PaymentVerificationResult> {
  const payment = await prisma.payment.findFirst({
    where: {
      bookingId: input.bookingId,
      provider: "RAZORPAY",
      providerRef: input.razorpayOrderId
    },
    include: {
      booking: true
    }
  });

  if (!payment) {
    throw new Error("Payment not found");
  }

  if (payment.booking.customerId !== input.userId) {
    throw new Error("Payment does not belong to this user");
  }

  if (payment.status === PaymentStatus.CAPTURED) {
    return {
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      paymentId: String(payment.notes && typeof payment.notes === "object" && "paymentId" in payment.notes ? (payment.notes as Record<string, unknown>).paymentId ?? input.razorpayPaymentId : input.razorpayPaymentId),
      status: payment.status
    };
  }

  if (!verifyRazorpaySignature({
    orderId: input.razorpayOrderId,
    paymentId: input.razorpayPaymentId,
    signature: input.razorpaySignature
  })) {
    throw new Error("Invalid payment signature");
  }

  await prisma.payment.update({
    where: { id: payment.id },
    data: {
      status: PaymentStatus.CAPTURED,
      providerRef: input.razorpayOrderId,
      notes: {
        ...(payment.notes && typeof payment.notes === "object" ? payment.notes as Record<string, unknown> : {}),
        paymentId: input.razorpayPaymentId,
        signature: input.razorpaySignature,
        verifiedAt: new Date().toISOString()
      }
    }
  });

  await prisma.booking.update({
    where: { id: payment.bookingId },
    data: {
      status: BookingStatus.ACCEPTED
    }
  });

  void dispatchBookingAfterPayment(payment.bookingId).catch((error) => {
    logger.error(
      {
        error,
        bookingId: payment.bookingId,
        bookingCode: payment.booking.code
      },
      "Automatic dispatch failed after payment verification"
    );
  });

  await publishTrackingEvent({
    bookingId: payment.bookingId,
    bookingCode: payment.booking.code,
    status: "PAYMENT_CAPTURED",
    message: "Payment verified successfully",
    actorRole: "CUSTOMER",
    paymentId: input.razorpayPaymentId
  });

  logger.info({
    bookingId: payment.bookingId,
    bookingCode: payment.booking.code,
    paymentId: input.razorpayPaymentId
  }, "Razorpay payment verified");

  return {
    bookingId: payment.bookingId,
    bookingCode: payment.booking.code,
    paymentId: input.razorpayPaymentId,
    status: PaymentStatus.CAPTURED
  };
}
