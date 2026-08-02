import { BookingStatus, CouponType, PaymentStatus, Prisma } from "@prisma/client";
import { createHmac, randomBytes } from "crypto";
import Razorpay from "razorpay";
import { env } from "../../config/env.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishTrackingEvent } from "../../lib/realtime.js";
import { recordBookingTimelineEvent } from "../../lib/booking-timeline.js";
import { dispatchBookingAfterPayment } from "../matching/matching.service.js";
import { raiseOpsAlert } from "../ops/ops.service.js";
import { getTokensForUser } from "../device-token/device-token.service.js";
import { sendMulticastPush } from "../../lib/fcm.js";
import { allocateProportionalShares, reverseInclusiveTax, roundMoney, toPaise } from "../../lib/gst.js";
import { generateInvoiceForBooking } from "../invoice/invoice.service.js";
import { assertServiceablePincode } from "../service-area/service-area.service.js";

type BookingItemInput = {
  serviceId: string;
  quantity?: number;
  variantSelections?: Record<string, unknown>;
};

type CreatePaymentOrderInput = {
  userId: string;
  cityId: string;
  items: BookingItemInput[];
  couponCode?: string;
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

type ServicePricingRule = {
  cityId: string | null;
  type: string;
  price: Prisma.Decimal;
  priority: number;
  createdAt: Date;
  startsAt: Date | null;
  endsAt: Date | null;
};

type ServicePricingRecord = {
  id: string;
  name: string;
  isActive: boolean;
  startingPrice: Prisma.Decimal;
  gstRate: Prisma.Decimal;
  sacCode: string | null;
  gstApplicable: boolean;
  subcategory: {
    id: string;
    name: string;
  };
  pricingRules: ServicePricingRule[];
};

type ResolvedBookingItem = {
  serviceId: string;
  serviceName: string;
  serviceSubcategoryId: string;
  quantity: number;
  unitPrice: Prisma.Decimal;
  totalPrice: Prisma.Decimal;
  gstRate: Prisma.Decimal;
  sacCode: string;
  variantSelections?: Record<string, unknown>;
};

const MINIMUM_ORDER_AMOUNT_PAISE = 100;
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

function asJsonRecord(value: Record<string, unknown> | undefined): Prisma.InputJsonValue {
  return (value ?? {}) as Prisma.InputJsonValue;
}

function now(): Date {
  return new Date();
}

function isRuleActive(rule: { startsAt: Date | null; endsAt: Date | null }, at: Date): boolean {
  if (rule.startsAt && rule.startsAt.getTime() > at.getTime()) {
    return false;
  }

  if (rule.endsAt && rule.endsAt.getTime() < at.getTime()) {
    return false;
  }

  return true;
}

function servicePriceRuleComparator(a: ServicePricingRule, b: ServicePricingRule): number {
  if (a.priority !== b.priority) {
    return b.priority - a.priority;
  }

  return b.createdAt.getTime() - a.createdAt.getTime();
}

function resolveServiceUnitPrice(service: ServicePricingRecord, cityId: string, at: Date): Prisma.Decimal {
  const activeRules = service.pricingRules.filter((rule) => isRuleActive(rule, at));
  const citySpecificRules = activeRules.filter((rule) => rule.cityId === cityId);
  const fallbackRules = activeRules.filter((rule) => rule.cityId === null);
  const candidateRules = citySpecificRules.length > 0 ? citySpecificRules : fallbackRules;

  if (candidateRules.length === 0) {
    return service.startingPrice;
  }

  const sortedRules = [...candidateRules].sort(servicePriceRuleComparator);
  const baseRule = sortedRules.find((rule) => rule.type === "BASE");
  return baseRule?.price ?? sortedRules[0].price;
}

async function ensureCity(cityId: string): Promise<void> {
  const city = await prisma.city.findUnique({
    where: { id: cityId },
    select: { id: true }
  });

  if (!city) {
    throw new Error("City not found");
  }
}

async function ensureBookingAddress(userId: string, cityId: string): Promise<string> {
  const existing = await prisma.address.findFirst({
    where: { userId, cityId },
    orderBy: [{ isDefault: "desc" }, { createdAt: "asc" }]
  });

  if (existing) {
    return existing.id;
  }

  throw new Error("Please add a valid saved address before placing a booking");
}

async function resolveCustomerContext(
  userId: string,
  cityId: string
): Promise<{
  user: {
    id: string;
    name: string;
    email: string | null;
    phone: string | null;
  };
  cityId: string;
  addressId: string;
}> {
  const [user, bookingCity] = await Promise.all([
    prisma.user.findUnique({
      where: { id: userId },
      include: { city: true }
    }),
    prisma.city.findUnique({
      where: { id: cityId },
      select: { id: true, name: true }
    })
  ]);

  if (!user) {
    throw new Error("User not found");
  }

  if (!bookingCity) {
    throw new Error("City not found");
  }

  if (!user.cityId) {
    await prisma.user.update({
      where: { id: userId },
      data: { cityId: bookingCity.id }
    });
  }

  const addressId = await ensureBookingAddress(userId, bookingCity.id);
  const address = await prisma.address.findFirst({
    where: { id: addressId, userId },
    select: { id: true, pincode: true }
  });

  if (!address) {
    throw new Error("Please add a valid saved address before placing a booking");
  }

  await assertServiceablePincode({
    pincode: address.pincode,
    cityId: bookingCity.id
  });

  return {
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone
    },
    cityId: bookingCity.id,
    addressId
  };
}

async function resolveBookingItems(input: {
  cityId: string;
  items: BookingItemInput[];
}): Promise<{
  items: ResolvedBookingItem[];
  subtotalAmount: Prisma.Decimal;
}> {
  const uniqueServiceIds = [...new Set(input.items.map((item) => item.serviceId))];

  if (uniqueServiceIds.length === 0) {
    throw new Error("At least one service must be selected");
  }

  const services = (await prisma.service.findMany({
    where: {
      id: { in: uniqueServiceIds },
      isActive: true
    },
    include: {
      subcategory: {
        select: {
          id: true,
          name: true
        }
      },
      pricingRules: {
        where: {
          isActive: true,
          OR: [{ cityId: null }, { cityId: input.cityId }]
        },
        orderBy: [{ priority: "desc" as const }, { createdAt: "desc" as const }]
      }
    }
  })) as ServicePricingRecord[];

  if (services.length !== uniqueServiceIds.length) {
    throw new Error("One or more selected services were not found");
  }

  const serviceById = new Map(services.map((service) => [service.id, service] as const));
  const at = now();

  const resolvedItems = input.items.map((item) => {
    const service = serviceById.get(item.serviceId);

    if (!service) {
      throw new Error("One or more selected services were not found");
    }

    const quantity = item.quantity ?? 1;
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("Quantity must be a positive integer");
    }

    const unitPrice = resolveServiceUnitPrice(service, input.cityId, at);
    const totalPrice = roundMoney(unitPrice.mul(quantity));

    return {
      serviceId: service.id,
      serviceName: service.name,
      serviceSubcategoryId: service.subcategory.id,
      quantity,
      unitPrice: roundMoney(unitPrice),
      totalPrice,
      gstRate: service.gstApplicable ? roundMoney(service.gstRate) : new Prisma.Decimal(0),
      sacCode: service.sacCode?.trim() || "PENDING",
      ...(item.variantSelections ? { variantSelections: item.variantSelections } : {})
    };
  });

  const subtotalAmount = roundMoney(
    resolvedItems.reduce((total, item) => total.add(item.totalPrice), new Prisma.Decimal(0))
  );

  return {
    items: resolvedItems,
    subtotalAmount
  };
}

async function resolveCouponDiscount(input: {
  couponCode?: string;
  subtotalAmount: Prisma.Decimal;
}): Promise<{
  couponCode: string | null;
  discountAmount: Prisma.Decimal;
}> {
  const normalizedCode = input.couponCode?.trim();

  if (!normalizedCode) {
    return {
      couponCode: null,
      discountAmount: new Prisma.Decimal(0)
    };
  }

  const coupon = await prisma.coupon.findFirst({
    where: {
      code: {
        equals: normalizedCode,
        mode: "insensitive"
      },
      isActive: true
    }
  });

  if (!coupon) {
    throw new Error("Invalid coupon code");
  }

  const at = now();
  if (coupon.startsAt && coupon.startsAt.getTime() > at.getTime()) {
    throw new Error("Coupon is not active yet");
  }

  if (coupon.endsAt && coupon.endsAt.getTime() < at.getTime()) {
    throw new Error("Coupon has expired");
  }

  if (coupon.minOrderAmount && input.subtotalAmount.lt(coupon.minOrderAmount)) {
    throw new Error("Order does not meet the minimum amount for this coupon");
  }

  let discountAmount = new Prisma.Decimal(0);

  if (coupon.type === CouponType.PERCENTAGE) {
    discountAmount = input.subtotalAmount.mul(coupon.value).div(100);
  } else if (coupon.type === CouponType.FIXED) {
    discountAmount = coupon.value;
  } else {
    throw new Error("Unsupported coupon type");
  }

  if (coupon.maxDiscount && discountAmount.gt(coupon.maxDiscount)) {
    discountAmount = coupon.maxDiscount;
  }

  if (discountAmount.gt(input.subtotalAmount)) {
    discountAmount = input.subtotalAmount;
  }

  return {
    couponCode: coupon.code,
    discountAmount: roundMoney(discountAmount)
  };
}

async function flagPaymentAmountMismatch(input: {
  paymentId: string;
  bookingId: string;
  bookingCode: string;
  expectedAmountPaise: number;
  recordedAmountPaise: number;
  razorpayAmountPaise: number;
  razorpayPaymentId: string;
  razorpayOrderId: string;
  signature: string;
  existingNotes: Prisma.JsonValue | null;
}): Promise<void> {
  await prisma.payment.update({
    where: { id: input.paymentId },
    data: {
      status: PaymentStatus.FAILED,
      notes: {
        ...(input.existingNotes && typeof input.existingNotes === "object" && !Array.isArray(input.existingNotes)
          ? (input.existingNotes as Record<string, unknown>)
          : {}),
        amountMismatch: true,
        expectedAmountPaise: input.expectedAmountPaise,
        recordedAmountPaise: input.recordedAmountPaise,
        razorpayAmountPaise: input.razorpayAmountPaise,
        razorpayPaymentId: input.razorpayPaymentId,
        razorpayOrderId: input.razorpayOrderId,
        signature: input.signature,
        flaggedAt: new Date().toISOString()
      } as Prisma.InputJsonValue
    }
  });

  await publishTrackingEvent({
    bookingId: input.bookingId,
    bookingCode: input.bookingCode,
    status: "PAYMENT_AMOUNT_MISMATCH",
    message: "Payment amount did not match the booking total",
    actorRole: "CUSTOMER",
    paymentId: input.razorpayPaymentId
  });

  await raiseOpsAlert({
    type: "payment_mismatch",
    sourceId: `payment_mismatch:${input.paymentId}`,
    bookingId: input.bookingId,
    severity: "critical",
    message: `Payment amount mismatch on booking ${input.bookingCode}: expected ${input.expectedAmountPaise}p, got ${input.razorpayAmountPaise}p from Razorpay.`,
    metadata: {
      title: `Payment mismatch \u2014 ${input.bookingCode}`,
      bookingCode: input.bookingCode,
      expectedAmountPaise: input.expectedAmountPaise,
      actualCapturedAmountPaise: input.razorpayAmountPaise,
      amount: input.razorpayAmountPaise / 100,
      timestamp: new Date().toISOString(),
      retryAvailable: false
    }
  });

  logger.warn(
    {
      bookingId: input.bookingId,
      bookingCode: input.bookingCode,
      expectedAmountPaise: input.expectedAmountPaise,
      recordedAmountPaise: input.recordedAmountPaise,
      razorpayAmountPaise: input.razorpayAmountPaise,
      razorpayOrderId: input.razorpayOrderId,
      razorpayPaymentId: input.razorpayPaymentId
    },
    "Payment amount mismatch detected"
  );
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

async function fetchRazorpayPayment(paymentId: string): Promise<{
  id: string;
  order_id: string | null;
  amount: number;
  currency: string | null;
  status: string | null;
}> {
  const paymentsClient = razorpay.payments as unknown as {
    fetch: (id: string) => Promise<{
      id: string;
      order_id?: string | null;
      amount?: number;
      currency?: string | null;
      status?: string | null;
    }>;
  };

  const payment = await paymentsClient.fetch(paymentId);

  return {
    id: payment.id,
    order_id: payment.order_id ?? null,
    amount: typeof payment.amount === "number" ? payment.amount : 0,
    currency: payment.currency ?? null,
    status: payment.status ?? null
  };
}

export async function createPaymentOrder(
  input: CreatePaymentOrderInput
): Promise<PaymentOrderResult> {
  const context = await resolveCustomerContext(input.userId, input.cityId);
  const bookingType = input.bookingType ?? "instant";
  const scheduledFor = bookingType === "scheduled" ? input.scheduledFor : undefined;
  const scheduledAt =
    bookingType === "scheduled" && scheduledFor
      ? scheduledFor
      : new Date(Date.now() + 24 * 60 * 60 * 1000);
  const bookingCode = formatBookingCode();

  const { items, subtotalAmount } = await resolveBookingItems({
    cityId: context.cityId,
    items: input.items
  });

  const { couponCode, discountAmount } = await resolveCouponDiscount({
    couponCode: input.couponCode,
    subtotalAmount
  });

  const discountShares = allocateProportionalShares(
    discountAmount,
    items.map((item) => item.totalPrice)
  );
  const bookedItems = items.map((item, index) => {
    const discountShare = discountShares[index] ?? new Prisma.Decimal(0);
    const netTotal = roundMoney(item.totalPrice.sub(discountShare));
    const { gstAmount } = reverseInclusiveTax(netTotal, item.gstRate);

    return {
      ...item,
      discountShare,
      netTotal,
      gstAmount
    };
  });

  const totalGstAmount = roundMoney(
    bookedItems.reduce((total, item) => total.add(item.gstAmount), new Prisma.Decimal(0))
  );
  const totalAmount = roundMoney(subtotalAmount.sub(discountAmount));
  const totalAmountPaise = toPaise(totalAmount);

  if (totalAmountPaise < MINIMUM_ORDER_AMOUNT_PAISE) {
    throw new Error("Final amount is below the minimum payable amount");
  }

  const bookingSummary = items.map((item) => `${item.serviceName} x${item.quantity}`).join(", ");
  const booking = await prisma.$transaction(async (tx) => {
    const createdBooking = await tx.booking.create({
      data: {
        code: bookingCode,
        customerId: context.user.id,
        bookingType,
        ...(scheduledFor ? { scheduledFor } : {}),
        cityId: context.cityId,
        addressId: context.addressId,
        status: BookingStatus.PENDING,
        scheduledAt,
        notes: couponCode ? `${bookingSummary} | Coupon: ${couponCode}` : bookingSummary,
        customerNotes: couponCode ? `${bookingSummary} | Coupon: ${couponCode}` : bookingSummary,
        subtotalAmount,
        discountAmount,
        taxAmount: totalGstAmount,
        totalAmount
      }
    });

    await tx.bookingService.createMany({
      data: bookedItems.map((item) => ({
        bookingId: createdBooking.id,
        serviceSubcategoryId: item.serviceSubcategoryId,
        serviceId: item.serviceId,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: item.totalPrice,
        gstRate: item.gstRate,
        gstAmount: item.gstAmount,
        sacCode: item.sacCode
      }))
    });

    await tx.payment.create({
      data: {
        bookingId: createdBooking.id,
        status: PaymentStatus.PENDING,
        provider: "RAZORPAY",
        amount: totalAmount,
        currency: "INR",
        notes: {
          bookingCode: createdBooking.code,
          cityId: context.cityId,
          couponCode,
          subtotalAmountPaise: toPaise(subtotalAmount),
          discountAmountPaise: toPaise(discountAmount),
          totalAmountPaise,
          items: items.map((item) => ({
            serviceId: item.serviceId,
            quantity: item.quantity,
            unitPricePaise: toPaise(item.unitPrice),
            totalPricePaise: toPaise(item.totalPrice),
            gstRate: item.gstRate.toString(),
            sacCode: item.sacCode
          }))
        }
      }
    });

    return createdBooking;
  });

  try {
    const order = (await razorpay.orders.create({
      amount: totalAmountPaise,
      currency: "INR",
      receipt: booking.code,
      notes: {
        bookingId: booking.id,
        bookingCode: booking.code,
        cityId: context.cityId,
        ...(couponCode ? { couponCode } : {})
      }
    })) as { id: string };

    await prisma.payment.updateMany({
      where: { bookingId: booking.id, provider: "RAZORPAY" },
      data: {
        providerRef: order.id,
        notes: {
          bookingCode: booking.code,
          cityId: context.cityId,
          ...(couponCode ? { couponCode } : {}),
          orderId: order.id,
          totalAmountPaise
        } as Prisma.InputJsonValue
      }
    });

    logger.info(
      {
        bookingId: booking.id,
        bookingCode: booking.code,
        orderId: order.id,
        userId: context.user.id,
        amountPaise: totalAmountPaise
      },
      "Razorpay order created"
    );

    await publishTrackingEvent({
      bookingId: booking.id,
      bookingCode: booking.code,
      status: "PAYMENT_PENDING",
      message: "Payment order created",
      actorRole: "CUSTOMER"
    });
    void recordBookingTimelineEvent({
      bookingId: booking.id,
      status: BookingStatus.PENDING,
      title: "Booking placed",
      description: "Your booking request was created and payment is pending."
    });

    return {
      keyId: env.RAZORPAY_KEY_ID ?? "",
      bookingId: booking.id,
      bookingCode: booking.code,
      orderId: order.id,
      amountPaise: totalAmountPaise,
      currency: "INR",
      customerName: context.user.name,
      customerEmail: context.user.email,
      customerPhone: context.user.phone
    };
  } catch (error) {
    await prisma.payment.updateMany({
      where: { bookingId: booking.id, provider: "RAZORPAY" },
      data: {
        status: PaymentStatus.FAILED,
        notes: {
          bookingCode: booking.code,
          cityId: context.cityId,
          ...(couponCode ? { couponCode } : {}),
          orderCreationFailedAt: new Date().toISOString()
        } as Prisma.InputJsonValue
      }
    });

    logger.error(
      {
        error,
        bookingId: booking.id,
        bookingCode: booking.code
      },
      "Failed to create Razorpay order"
    );
    throw error;
  }
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

  if (!verifyRazorpaySignature({
    orderId: input.razorpayOrderId,
    paymentId: input.razorpayPaymentId,
    signature: input.razorpaySignature
  })) {
    throw new Error("Invalid payment signature");
  }

  const expectedAmountPaise = toPaise(payment.booking.totalAmount);
  const recordedAmountPaise = toPaise(payment.amount);

  if (recordedAmountPaise !== expectedAmountPaise) {
    await flagPaymentAmountMismatch({
      paymentId: payment.id,
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      expectedAmountPaise,
      recordedAmountPaise,
      razorpayAmountPaise: recordedAmountPaise,
      razorpayPaymentId: input.razorpayPaymentId,
      razorpayOrderId: input.razorpayOrderId,
      signature: input.razorpaySignature,
      existingNotes: payment.notes
    });

    throw new Error("Payment amount mismatch");
  }

  const razorpayPayment = await fetchRazorpayPayment(input.razorpayPaymentId);

  if (razorpayPayment.order_id !== input.razorpayOrderId) {
    await flagPaymentAmountMismatch({
      paymentId: payment.id,
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      expectedAmountPaise,
      recordedAmountPaise,
      razorpayAmountPaise: razorpayPayment.amount ?? 0,
      razorpayPaymentId: input.razorpayPaymentId,
      razorpayOrderId: input.razorpayOrderId,
      signature: input.razorpaySignature,
      existingNotes: payment.notes
    });

    throw new Error("Payment order does not match the Razorpay payment");
  }

  if (razorpayPayment.status !== "captured") {
    throw new Error("Payment has not been captured by Razorpay");
  }

  const razorpayAmountPaise = typeof razorpayPayment.amount === "number" ? razorpayPayment.amount : 0;

  if (razorpayAmountPaise !== expectedAmountPaise) {
    await flagPaymentAmountMismatch({
      paymentId: payment.id,
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      expectedAmountPaise,
      recordedAmountPaise,
      razorpayAmountPaise,
      razorpayPaymentId: input.razorpayPaymentId,
      razorpayOrderId: input.razorpayOrderId,
      signature: input.razorpaySignature,
      existingNotes: payment.notes
    });

    throw new Error("Payment amount mismatch");
  }

  if (payment.status === PaymentStatus.CAPTURED) {
    await generateInvoiceForBooking(payment.bookingId);
    return {
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      paymentId: String(
        payment.notes && typeof payment.notes === "object" && "paymentId" in payment.notes
          ? (payment.notes as Record<string, unknown>).paymentId ?? input.razorpayPaymentId
          : input.razorpayPaymentId
      ),
      status: payment.status
    };
  }

  await prisma.payment.update({
    where: { id: payment.id },
    data: {
      status: PaymentStatus.CAPTURED,
      providerRef: input.razorpayOrderId,
      notes: {
        ...(payment.notes && typeof payment.notes === "object" ? (payment.notes as Record<string, unknown>) : {}),
        paymentId: input.razorpayPaymentId,
        signature: input.razorpaySignature,
        verifiedAt: new Date().toISOString(),
        razorpayAmountPaise
      } as Prisma.InputJsonValue
    }
  });

  await prisma.booking.update({
    where: { id: payment.bookingId },
    data: {
      status: BookingStatus.ACCEPTED
    }
  });

  await generateInvoiceForBooking(payment.bookingId);

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
  void recordBookingTimelineEvent({
    bookingId: payment.bookingId,
    status: BookingStatus.ACCEPTED,
    title: "Payment captured",
    description: "Payment was verified successfully and the booking moved forward."
  });

  logger.info(
    {
      bookingId: payment.bookingId,
      bookingCode: payment.booking.code,
      paymentId: input.razorpayPaymentId,
      amountPaise: razorpayAmountPaise
    },
    "Razorpay payment verified"
  );

  // Send booking confirmation push to customer
  try {
    const tokens = await getTokensForUser(input.userId);
    if (tokens.length > 0) {
      await sendMulticastPush({
        tokens,
        title: "Booking Confirmed!",
        body: `Your booking #${payment.booking.code} has been confirmed. A professional will be assigned shortly.`,
        data: {
          type: "BOOKING_CONFIRMED",
          bookingId: payment.bookingId,
          bookingCode: payment.booking.code,
          route: `/booking/${payment.bookingId}`
        }
      });
    }
  } catch (err) {
    logger.warn({ err }, "Failed to send booking confirmed push");
  }

  return {
    bookingId: payment.bookingId,
    bookingCode: payment.booking.code,
    paymentId: input.razorpayPaymentId,
    status: PaymentStatus.CAPTURED
  };
}
