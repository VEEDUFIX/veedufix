import { beforeEach, describe, expect, it, vi } from "vitest";
import { PaymentStatus } from "@prisma/client";

const mocks = vi.hoisted(() => ({
  paymentFindFirst: vi.fn(),
  paymentFindUnique: vi.fn(),
  orderFetch: vi.fn(),
  orderFetchPayments: vi.fn(),
  updatePaymentForWebhook: vi.fn()
}));

vi.mock("../lib/prisma.js", () => ({
  prisma: {
    payment: {
      findFirst: mocks.paymentFindFirst,
      findUnique: mocks.paymentFindUnique
    }
  }
}));
vi.mock("../config/env.js", () => ({
  env: {
    RAZORPAY_KEY_ID: "test-key",
    RAZORPAY_KEY_SECRET: "test-secret",
    RAZORPAY_WEBHOOK_URL: "https://example.test/webhook"
  }
}));
vi.mock("razorpay", () => ({
  default: class MockRazorpay {
    orders = {
      fetch: mocks.orderFetch,
      fetchPayments: mocks.orderFetchPayments
    };
  }
}));
vi.mock("../modules/webhooks/webhooks.service.js", () => ({
  updatePaymentForWebhook: mocks.updatePaymentForWebhook
}));
vi.mock("../lib/logger.js", () => ({ logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() } }));
vi.mock("../lib/realtime.js", () => ({ publishNotificationEvent: vi.fn(), publishTrackingEvent: vi.fn() }));
vi.mock("../lib/booking-timeline.js", () => ({ recordBookingTimelineEvent: vi.fn() }));
vi.mock("../modules/matching/matching.service.js", () => ({
  dispatchBookingAfterPayment: vi.fn(),
  hasAvailablePartnersForInstantBooking: vi.fn()
}));
vi.mock("../modules/ops/ops.service.js", () => ({ raiseOpsAlert: vi.fn() }));
vi.mock("../modules/device-token/device-token.service.js", () => ({ getTokensForUser: vi.fn() }));
vi.mock("../lib/fcm.js", () => ({ sendMulticastPush: vi.fn() }));
vi.mock("../modules/invoice/invoice.service.js", () => ({ generateInvoiceForBooking: vi.fn() }));
vi.mock("../modules/service-area/service-area.service.js", () => ({ assertServiceablePincode: vi.fn() }));
vi.mock("../modules/availability/availability.service.js", () => ({ getCustomerScheduleSlots: vi.fn() }));
vi.mock("../modules/catalog/availability-inheritance.js", () => ({ isAvailableInAreas: vi.fn() }));
vi.mock("../modules/payments/diagnostic-photo-attachments.js", () => ({ attachDiagnosticPhotosToBooking: vi.fn() }));

import { getPaymentOrderStatus, isPaymentOrderSafeToAbandon } from "../modules/payments/payments.service.js";

const orderId = "order_123";
const bookingId = "booking_123";
const userId = "customer_123";

function request() {
  return { bookingId, userId, razorpayOrderId: orderId };
}

describe("getPaymentOrderStatus", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.PENDING,
      customQuoteRevisionId: null,
      notes: null,
      createdAt: new Date()
    });
    mocks.paymentFindUnique.mockResolvedValue({ status: PaymentStatus.CAPTURED });
    mocks.orderFetch.mockResolvedValue({
      id: orderId,
      status: "created",
      created_at: Math.floor(Date.now() / 1000)
    });
    mocks.orderFetchPayments.mockResolvedValue({ items: [] });
  });

  it("does not reconcile a captured payment belonging to another order", async () => {
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "payment_other", order_id: "order_other", status: "captured", amount: 5000 }]
    });

    await expect(getPaymentOrderStatus(request())).resolves.toBe(PaymentStatus.PENDING);

    expect(mocks.updatePaymentForWebhook).not.toHaveBeenCalled();
    expect(mocks.paymentFindFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ booking: { customerId: userId } })
    }));
  });

  it("uses order-scoped payment attempts to reconcile a capture", async () => {
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "payment_123", order_id: orderId, status: "captured", amount: 12500 }]
    });

    await expect(getPaymentOrderStatus(request())).resolves.toBe(PaymentStatus.CAPTURED);

    expect(mocks.orderFetchPayments).toHaveBeenCalledWith(orderId);
    expect(mocks.updatePaymentForWebhook).toHaveBeenCalledWith(
      orderId,
      PaymentStatus.CAPTURED,
      expect.objectContaining({ paymentId: "payment_123" }),
      12500
    );
  });

  it("keeps an old payable order pending because age does not prove provider expiry", async () => {
    const oldCreatedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.PENDING,
      customQuoteRevisionId: null,
      createdAt: oldCreatedAt
    });
    mocks.orderFetch.mockResolvedValue({
      id: orderId,
      status: "attempted",
      created_at: Math.floor(oldCreatedAt.getTime() / 1000)
    });
    await expect(getPaymentOrderStatus(request())).resolves.toBe(PaymentStatus.PENDING);
    expect(mocks.updatePaymentForWebhook).not.toHaveBeenCalled();
  });

  it("keeps an old order pending while an attempt is still authorized", async () => {
    const oldCreatedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.PENDING,
      customQuoteRevisionId: null,
      createdAt: oldCreatedAt
    });
    mocks.orderFetch.mockResolvedValue({
      id: orderId,
      status: "attempted",
      created_at: Math.floor(oldCreatedAt.getTime() / 1000)
    });
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "payment_123", order_id: orderId, status: "authorized", amount: 12500 }]
    });

    await expect(getPaymentOrderStatus(request())).resolves.toBe(PaymentStatus.PENDING);
    expect(mocks.updatePaymentForWebhook).not.toHaveBeenCalled();
  });

  it("keeps an order pending after failed attempts while Razorpay still reports it attempted", async () => {
    const oldCreatedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.FAILED,
      customQuoteRevisionId: null,
      createdAt: oldCreatedAt
    });
    mocks.orderFetch.mockResolvedValue({
      id: orderId,
      status: "attempted",
      created_at: Math.floor(oldCreatedAt.getTime() / 1000)
    });
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "attempt_123", order_id: orderId, status: "failed", amount: 12500 }]
    });

    await expect(getPaymentOrderStatus(request())).resolves.toBe(PaymentStatus.PENDING);
    expect(mocks.updatePaymentForWebhook).not.toHaveBeenCalled();
  });
});

describe("isPaymentOrderSafeToAbandon", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.PENDING,
      customQuoteRevisionId: null,
      notes: null,
      createdAt: new Date()
    });
    mocks.orderFetch.mockResolvedValue({ id: orderId, status: "created" });
    mocks.orderFetchPayments.mockResolvedValue({ items: [] });
  });

  it("allows abandonment when there are no captured, authorized, or unresolved attempts", async () => {
    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(true);

    mocks.orderFetch.mockResolvedValue({ id: orderId, status: "attempted" });
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "attempt_123", order_id: orderId, status: "failed", amount: 12500 }]
    });
    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(true);
  });

  it("keeps authorized and unknown attempts linked", async () => {
    mocks.orderFetch.mockResolvedValue({ id: orderId, status: "attempted" });
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "attempt_123", order_id: orderId, status: "authorized", amount: 12500 }]
    });
    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(false);

    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "attempt_123", order_id: orderId, status: "processing", amount: 12500 }]
    });
    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(false);
  });

  it("reconciles captures and keeps their checkouts linked", async () => {
    mocks.orderFetch.mockResolvedValue({ id: orderId, status: "paid" });
    mocks.orderFetchPayments.mockResolvedValue({
      items: [{ id: "payment_123", order_id: orderId, status: "captured", amount: 12500 }]
    });

    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(false);
    expect(mocks.updatePaymentForWebhook).toHaveBeenCalledWith(
      orderId,
      PaymentStatus.CAPTURED,
      expect.objectContaining({ paymentId: "payment_123" }),
      12500
    );
  });

  it("does not abandon a locally flagged amount-mismatched capture", async () => {
    mocks.paymentFindFirst.mockResolvedValue({
      id: "payment_123",
      status: PaymentStatus.FAILED,
      customQuoteRevisionId: null,
      notes: { amountMismatch: true },
      createdAt: new Date()
    });

    await expect(isPaymentOrderSafeToAbandon(request())).resolves.toBe(false);
    expect(mocks.orderFetch).not.toHaveBeenCalled();
  });
});
