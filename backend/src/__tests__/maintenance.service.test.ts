import { beforeEach, describe, expect, it, vi } from "vitest";
import { BookingStatus, MaintenanceOccurrenceStatus, MaintenancePlanStatus, PaymentStatus } from "@prisma/client";

const { prismaMock, txMock, sendToRecipient, logger } = vi.hoisted(() => {
  const txMock = {
    maintenanceOccurrence: { findFirst: vi.fn(), updateMany: vi.fn(), create: vi.fn() },
    booking: { updateMany: vi.fn() },
    payment: { updateMany: vi.fn(), findUnique: vi.fn() },
    user: { update: vi.fn() },
    walletTransaction: { findFirst: vi.fn(), create: vi.fn() },
    maintenancePlanEvent: { create: vi.fn() },
    maintenancePlan: { updateMany: vi.fn(), create: vi.fn(), update: vi.fn(), findUniqueOrThrow: vi.fn() }
  };
  return {
    txMock,
    prismaMock: {
      $transaction: vi.fn(async (callback: (tx: typeof txMock) => unknown) => callback(txMock)),
      maintenanceOccurrence: { findMany: vi.fn(), updateMany: vi.fn() },
      maintenancePlan: { findMany: vi.fn(), findFirst: vi.fn() },
      service: { findFirst: vi.fn() },
      serviceVariant: { findFirst: vi.fn() }
    },
    sendToRecipient: vi.fn(),
    logger: { warn: vi.fn(), error: vi.fn() }
  };
});

vi.mock("../lib/prisma.js", () => ({ prisma: prismaMock }));
vi.mock("../lib/logger.js", () => ({ logger }));
vi.mock("../modules/scheduler/lifecycle-notifications.js", () => ({ sendToRecipient }));
vi.mock("../modules/payments/payments.service.js", () => ({
  resolveCustomerContext: vi.fn(),
  isPaymentOrderSafeToAbandon: vi.fn()
}));

import {
  addMonthsUtc,
  calendarDateInTimezone,
  confirmOccurrenceBookingLink,
  localDateTimeToUtc,
  createCustomerMaintenancePlan,
  processMaintenancePlanOccurrences
} from "../modules/maintenance/maintenance.service.js";
import { isPaymentOrderSafeToAbandon, resolveCustomerContext } from "../modules/payments/payments.service.js";

describe("maintenance plan lifecycle", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(false);
    prismaMock.maintenanceOccurrence.findMany.mockResolvedValue([]);
    prismaMock.maintenancePlan.findMany.mockResolvedValue([]);
    txMock.payment.updateMany.mockResolvedValue({ count: 1 });
    txMock.booking.updateMany.mockResolvedValue({ count: 1 });
    txMock.walletTransaction.findFirst.mockResolvedValue(null);
    txMock.user.update.mockResolvedValue({ walletBalance: 75 });
    txMock.maintenancePlan.create.mockResolvedValue({ id: "plan-1" });
    txMock.maintenancePlan.findUniqueOrThrow.mockResolvedValue({ id: "plan-1" });
    txMock.maintenanceOccurrence.create.mockResolvedValue({ id: "occurrence-1" });
    prismaMock.service.findFirst.mockResolvedValue({ id: "service-1" });
    prismaMock.serviceVariant.findFirst.mockResolvedValue(null);
  });

  it("adds months without drifting from month-end dates", () => {
    const jan31 = new Date(Date.UTC(2024, 0, 31));
    expect(addMonthsUtc(jan31, 1)).toEqual(new Date(Date.UTC(2024, 1, 29)));
    expect(addMonthsUtc(jan31, 2)).toEqual(new Date(Date.UTC(2024, 2, 31)));
  });

  it("uses the plan timezone for calendar dates and reminder instants", () => {
    const now = new Date("2026-10-12T01:00:00.000Z");
    expect(calendarDateInTimezone(now, "Asia/Kolkata")).toEqual(
      new Date(Date.UTC(2026, 9, 12))
    );
    expect(localDateTimeToUtc(new Date(Date.UTC(2026, 9, 12)), "09:00", "Asia/Kolkata"))
      .toEqual(new Date("2026-10-12T03:30:00.000Z"));
    expect(localDateTimeToUtc(new Date(Date.UTC(2026, 2, 8)), "02:30", "America/New_York"))
      .toEqual(new Date("2026-03-08T07:00:00.000Z"));
  });

  it("paginates past-due reminder candidates so they cannot hide future reminders", async () => {
    const now = new Date("2026-10-14T01:00:00.000Z");
    const oldRows = Array.from({ length: 200 }, (_, index) => ({
      id: `past-${String(index).padStart(3, "0")}`,
      planId: "plan-old",
      dueAt: new Date("2026-10-13T00:00:00.000Z"),
      sequence: index + 1,
      plan: {
        id: "plan-old",
        customerId: "customer-old",
        timezone: "America/Adak",
        preferredTime: "09:00",
        service: { name: "Old visit", maintenanceReminderHours: 24 }
      }
    }));
    const futureReminder = {
      id: "future-reminder",
      planId: "plan-new",
      dueAt: new Date("2026-10-14T00:00:00.000Z"),
      sequence: 1,
      plan: {
        id: "plan-new",
        customerId: "customer-new",
        timezone: "America/Adak",
        preferredTime: "09:00",
        service: { name: "Upcoming visit", maintenanceReminderHours: 24 }
      }
    };
    prismaMock.maintenanceOccurrence.findMany.mockImplementation(async (args: any) => {
      if (args.where?.status !== MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION) return [] as never;
      if (!args.cursor) return oldRows as never;
      if (args.cursor.id === "past-199") return [futureReminder] as never;
      return [] as never;
    });

    await processMaintenancePlanOccurrences(now);

    expect(sendToRecipient).toHaveBeenCalledTimes(1);
    expect(sendToRecipient).toHaveBeenCalledWith(expect.objectContaining({
      userId: "customer-new",
      data: expect.objectContaining({ occurrenceId: "future-reminder" })
    }));
    const reminderQueries = prismaMock.maintenanceOccurrence.findMany.mock.calls.filter(
      ([args]) => args.where?.status === MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION
    );
    expect(reminderQueries.length).toBe(2);
    expect(reminderQueries[1][0]).toMatchObject({ cursor: { id: "past-199" }, skip: 1, take: 200 });
  });

  it("claims each generated occurrence once when scheduler sweeps overlap", async () => {
    const startAt = new Date(Date.UTC(2026, 0, 31));
    const nextDueAt = new Date(Date.UTC(2026, 1, 28));
    prismaMock.maintenancePlan.findMany.mockResolvedValue([
      { id: "plan-1", startAt, endAt: null, nextDueAt, nextSequence: 2, intervalMonths: 1, timezone: "Asia/Kolkata" }
    ] as never);
    txMock.maintenancePlan.updateMany
      .mockResolvedValueOnce({ count: 1 })
      .mockResolvedValueOnce({ count: 0 });
    const now = new Date(Date.UTC(2026, 0, 31));
    await Promise.all([
      processMaintenancePlanOccurrences(now),
      processMaintenancePlanOccurrences(now)
    ]);
    expect(txMock.maintenancePlan.updateMany).toHaveBeenCalledTimes(2);
    expect(txMock.maintenanceOccurrence.create).toHaveBeenCalledTimes(1);
    expect(txMock.maintenanceOccurrence.create).toHaveBeenCalledWith({
      data: { planId: "plan-1", sequence: 2, dueAt: nextDueAt }
    });
  });

  it("excludes plans whose end date is before the sweep date", async () => {
    const now = new Date("2026-10-13T12:00:00.000Z");
    prismaMock.maintenancePlan.findMany.mockResolvedValueOnce([]);

    await processMaintenancePlanOccurrences(now);

    expect(prismaMock.maintenancePlan.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        status: "ACTIVE",
        nextDueAt: { lte: new Date(now.getTime() + 45 * 24 * 60 * 60 * 1000) },
        OR: [
          { endAt: null },
          { endAt: { gte: new Date(Date.UTC(2026, 9, 13)) } }
        ]
      })
    }));
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it("continues generating occurrences after an individual plan transaction fails", async () => {
    const startAt = new Date(Date.UTC(2026, 0, 31));
    const dueAt = startAt;
    prismaMock.maintenancePlan.findMany.mockResolvedValue([
      { id: "plan-failed", startAt, endAt: null, nextDueAt: dueAt, nextSequence: 1, intervalMonths: 1, timezone: "Asia/Kolkata" },
      { id: "plan-succeeds", startAt, endAt: null, nextDueAt: dueAt, nextSequence: 1, intervalMonths: 1, timezone: "Asia/Kolkata" }
    ] as never);
    txMock.maintenancePlan.updateMany.mockResolvedValue({ count: 1 });
    prismaMock.$transaction.mockRejectedValueOnce(new Error("database constraint failure"));

    await processMaintenancePlanOccurrences(new Date(Date.UTC(2026, 0, 31)));

    expect(prismaMock.$transaction).toHaveBeenCalledTimes(2);
    expect(txMock.maintenanceOccurrence.create).toHaveBeenCalledTimes(1);
    expect(txMock.maintenanceOccurrence.create).toHaveBeenCalledWith({
      data: { planId: "plan-succeeds", sequence: 1, dueAt }
    });
    expect(logger.warn).toHaveBeenCalledWith(
      expect.objectContaining({ planId: "plan-failed" }),
      "Maintenance occurrence generation failed for plan"
    );
  });

  it("skips past-due visits after a plan resumes and generates the next future visit", async () => {
    const startAt = new Date(Date.UTC(2026, 0, 31));
    const staleDueAt = new Date(Date.UTC(2026, 1, 28));
    const nextFutureDueAt = new Date(Date.UTC(2026, 4, 31));
    prismaMock.maintenancePlan.findMany.mockResolvedValueOnce([{
      id: "plan-1",
      startAt,
      endAt: null,
      nextDueAt: staleDueAt,
      nextSequence: 2,
      intervalMonths: 1,
      timezone: "Asia/Kolkata"
    }] as never);
    txMock.maintenancePlan.updateMany.mockResolvedValueOnce({ count: 1 });

    await processMaintenancePlanOccurrences(new Date("2026-05-15T12:00:00.000Z"));

    expect(txMock.maintenancePlan.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: "plan-1", nextSequence: 2, nextDueAt: staleDueAt }),
      data: { nextSequence: 6, nextDueAt: new Date(Date.UTC(2026, 5, 30)) }
    }));
    expect(txMock.maintenanceOccurrence.create).toHaveBeenCalledWith({
      data: { planId: "plan-1", sequence: 5, dueAt: nextFutureDueAt }
    });
    expect(txMock.maintenancePlanEvent.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        planId: "plan-1",
        action: "MISSED_OCCURRENCES_SKIPPED",
        details: expect.objectContaining({ fromSequence: 2, throughSequence: 4, count: 3 })
      })
    }));
  });
  it("links only the customer's active plan occurrence for its scheduled date", async () => {
    txMock.maintenanceOccurrence.findFirst.mockResolvedValue({
      id: "occurrence-1",
      planId: "plan-1",
      dueAt: new Date(Date.UTC(2026, 10, 12)),
      plan: { timezone: "Asia/Kolkata" }
    });
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });
    await confirmOccurrenceBookingLink({
      tx: txMock as never,
      customerId: "customer-1",
      occurrenceId: "occurrence-1",
      serviceId: "service-1",
      variantId: "variant-1",
      addressId: "address-1",
      bookingId: "booking-1",
      scheduledFor: new Date(Date.UTC(2026, 10, 12, 9))
    });
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "occurrence-1", status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION, bookingId: null },
      data: expect.objectContaining({ status: MaintenanceOccurrenceStatus.BOOKING_CREATED, bookingId: "booking-1" })
    }));
    expect(txMock.maintenancePlanEvent.create).toHaveBeenCalledOnce();
  });

  it("rejects a booking linked to a different date", async () => {
    txMock.maintenanceOccurrence.findFirst.mockResolvedValue({
      id: "occurrence-1",
      planId: "plan-1",
      dueAt: new Date(Date.UTC(2026, 10, 12)),
      plan: { timezone: "Asia/Kolkata" }
    });
    await expect(confirmOccurrenceBookingLink({
      tx: txMock as never,
      customerId: "customer-1",
      occurrenceId: "occurrence-1",
      serviceId: "service-1",
      addressId: "address-1",
      bookingId: "booking-1",
      scheduledFor: new Date(Date.UTC(2026, 10, 13, 9))
    })).rejects.toMatchObject({ statusCode: 400 });
    expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
  });

  it("matches a scheduled instant using the maintenance plan timezone", async () => {
    txMock.maintenanceOccurrence.findFirst.mockResolvedValue({
      id: "occurrence-1",
      planId: "plan-1",
      dueAt: new Date(Date.UTC(2026, 10, 12)),
      plan: { timezone: "Pacific/Kiritimati" }
    });
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });

    await confirmOccurrenceBookingLink({
      tx: txMock as never,
      customerId: "customer-1",
      occurrenceId: "occurrence-1",
      serviceId: "service-1",
      addressId: "address-1",
      bookingId: "booking-1",
      // Nov 12 at 00:30 in Kiritimati is Nov 11 in UTC.
      scheduledFor: new Date("2026-11-11T10:30:00.000Z")
    });

    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledOnce();
  });

  it("releases a linked occurrence when its booking was cancelled", async () => {
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: { id: "booking-1", status: BookingStatus.CANCELLED_MANUAL, createdAt: new Date(), payments: [] }
      }])
      .mockResolvedValueOnce([]);
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });
    await processMaintenancePlanOccurrences(new Date(Date.UTC(2026, 9, 12)));
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "occurrence-1", bookingId: "booking-1", status: MaintenanceOccurrenceStatus.BOOKING_CREATED },
      data: expect.objectContaining({ bookingId: null, status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION })
    }));
    expect(txMock.maintenancePlanEvent.create).toHaveBeenCalledOnce();
  });

  it("continues reconciling linked bookings after an individual transaction fails", async () => {
    const cancelledOccurrence = (id: string, bookingId: string) => ({
      id,
      planId: "plan-1",
      bookingId,
      plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
      booking: { id: bookingId, status: BookingStatus.CANCELLED_MANUAL, createdAt: new Date(), payments: [] }
    });
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([cancelledOccurrence("occurrence-failed", "booking-failed"), cancelledOccurrence("occurrence-succeeds", "booking-succeeds")] as never)
      .mockResolvedValueOnce([]);
    prismaMock.$transaction.mockRejectedValueOnce(new Error("database constraint failure"));

    await processMaintenancePlanOccurrences();

    expect(prismaMock.$transaction).toHaveBeenCalledTimes(2);
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledTimes(1);
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "occurrence-succeeds", bookingId: "booking-succeeds", status: MaintenanceOccurrenceStatus.BOOKING_CREATED }
    }));
    expect(logger.warn).toHaveBeenCalledWith(
      expect.objectContaining({ occurrenceId: "occurrence-failed", bookingId: "booking-failed" }),
      "Maintenance occurrence reconciliation failed"
    );
  });

  it("waits through the payment grace period before cancelling a booking whose payment failed", async () => {
    const failedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt: failedAt,
          payments: [{ id: "payment-1", status: PaymentStatus.FAILED, createdAt: failedAt, notes: {}, provider: "RAZORPAY", providerRef: "order-1", customQuoteRevisionId: null }]
        }
      }])
      .mockResolvedValueOnce([]);
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(true);
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });
    await processMaintenancePlanOccurrences();
    expect(isPaymentOrderSafeToAbandon).toHaveBeenCalledWith({
      userId: "customer-1",
      bookingId: "booking-1",
      razorpayOrderId: "order-1"
    });
    expect(txMock.booking.updateMany).toHaveBeenCalledWith({
      where: { id: "booking-1", status: BookingStatus.PENDING },
      data: {
        status: BookingStatus.CANCELLED_MANUAL,
        clientRequestKey: null,
        clientRequestHash: null
      }
    });
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ bookingId: null, status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION, failureReason: "Payment failed" })
    }));
  });

  it("keeps an amount-mismatched capture linked and does not restore its wallet debit", async () => {
    const abandonedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt: abandonedAt,
          payments: [{
            id: "payment-1",
            status: PaymentStatus.FAILED,
            createdAt: abandonedAt,
            notes: { amountMismatch: true, walletDeductAmountPaise: 2500 },
            provider: "RAZORPAY",
            providerRef: "order-1",
            customQuoteRevisionId: null
          }]
        }
      }] as never)
      .mockResolvedValueOnce([]);

    await processMaintenancePlanOccurrences();

    expect(isPaymentOrderSafeToAbandon).not.toHaveBeenCalled();
    expect(txMock.booking.updateMany).not.toHaveBeenCalled();
    expect(txMock.user.update).not.toHaveBeenCalled();
    expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
  });

  it("keeps a recently failed payment linked so the customer can retry", async () => {
    prismaMock.maintenanceOccurrence.findMany.mockResolvedValueOnce([{
      id: "occurrence-1",
      planId: "plan-1",
      bookingId: "booking-1",
      plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
      booking: {
        id: "booking-1",
        customerId: "customer-1",
        status: BookingStatus.PENDING,
        createdAt: new Date(),
        payments: [{ id: "payment-1", status: PaymentStatus.FAILED, createdAt: new Date(), notes: {} }]
      }
    }] as never);

    await processMaintenancePlanOccurrences();

    expect(txMock.booking.updateMany).not.toHaveBeenCalled();
    expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
  });

  it("processes cancelled bookings even when old payable checkouts fill the pending batch", async () => {
    const abandonedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    const pendingOccurrence = {
      id: "occurrence-pending",
      planId: "plan-pending",
      bookingId: "booking-pending",
      plan: { id: "plan-pending", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
      booking: {
        id: "booking-pending",
        customerId: "customer-1",
        status: BookingStatus.PENDING,
        createdAt: abandonedAt,
        payments: [{
          id: "payment-pending",
          status: PaymentStatus.PENDING,
          createdAt: abandonedAt,
          notes: {},
          provider: "RAZORPAY",
          providerRef: "order-pending",
          customQuoteRevisionId: null
        }]
      }
    };
    const cancelledOccurrence = {
      id: "occurrence-cancelled",
      planId: "plan-cancelled",
      bookingId: "booking-cancelled",
      plan: { id: "plan-cancelled", customerId: "customer-2", status: MaintenancePlanStatus.ACTIVE },
      booking: {
        id: "booking-cancelled",
        customerId: "customer-2",
        status: BookingStatus.CANCELLED,
        createdAt: abandonedAt,
        payments: []
      }
    };
    prismaMock.maintenanceOccurrence.findMany.mockImplementation(async (args: any) => {
      if (args.where?.booking?.status?.in) return [cancelledOccurrence] as never;
      if (args.where?.booking?.status === BookingStatus.PENDING) return [pendingOccurrence] as never;
      return [];
    });
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(false);

    await processMaintenancePlanOccurrences();

    const reconciliationCalls = prismaMock.maintenanceOccurrence.findMany.mock.calls.slice(0, 2);
    expect(reconciliationCalls[0][0].where.booking.status.in).toContain(BookingStatus.CANCELLED);
    expect(reconciliationCalls[1][0].where.booking.status).toBe(BookingStatus.PENDING);
    expect(isPaymentOrderSafeToAbandon).toHaveBeenCalledWith({
      userId: "customer-1",
      bookingId: "booking-pending",
      razorpayOrderId: "order-pending"
    });
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "occurrence-cancelled", bookingId: "booking-cancelled", status: MaintenanceOccurrenceStatus.BOOKING_CREATED },
      data: expect.objectContaining({ bookingId: null, failureReason: "Linked booking was cancelled" })
    }));
    expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: "occurrence-pending" })
    }));
  });

  it("resolves a submitted saved-address ID to the canonical booking address", async () => {
    vi.mocked(resolveCustomerContext).mockResolvedValue({
      user: { id: "customer-1", name: "Customer", email: null, phone: null },
      cityId: "city-1",
      addressId: "canonical-address-1",
      serviceAreaIds: ["area-1"]
    });
    txMock.maintenancePlan.update.mockResolvedValue(undefined);
    txMock.maintenancePlanEvent.create.mockResolvedValue(undefined);
    txMock.maintenanceOccurrence.create.mockResolvedValue(undefined);

    await createCustomerMaintenancePlan("customer-1", {
      serviceId: "service-1",
      addressId: "saved-address-1",
      intervalMonths: 1,
      startAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
        .toISOString()
        .slice(0, 10),
      timezone: "Asia/Kolkata"
    });

    expect(resolveCustomerContext).toHaveBeenCalledWith("customer-1", undefined, "saved-address-1");
    expect(txMock.maintenancePlan.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ addressId: "canonical-address-1" })
    }));
  });

  it("rejects a maintenance plan when active variants are unavailable in the selected area", async () => {
    vi.mocked(resolveCustomerContext).mockResolvedValue({
      user: { id: "customer-1", name: "Customer", email: null, phone: null },
      cityId: "city-1",
      addressId: "address-1",
      serviceAreaIds: ["area-1"]
    });
    prismaMock.service.findFirst.mockResolvedValue({ id: "service-1" } as never);
    vi.mocked(prismaMock.serviceVariant.findFirst)
      .mockResolvedValueOnce({ id: "variant-inactive-area" } as never)
      .mockResolvedValueOnce(null as never);

    await expect(createCustomerMaintenancePlan("customer-1", {
      serviceId: "service-1",
      addressId: "address-1",
      intervalMonths: 1,
      startAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10),
      timezone: "Asia/Kolkata"
    })).rejects.toThrow("No service option is available at this address");
    expect(txMock.maintenancePlan.create).not.toHaveBeenCalled();
  });

  it("cancels an abandoned payment checkout and releases its occurrence", async () => {
    const now = new Date();
    const abandonedAt = new Date(now.getTime() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt: abandonedAt,
          payments: [{
            id: "payment-1",
            status: PaymentStatus.PENDING,
            createdAt: abandonedAt,
            notes: { walletDeductAmountPaise: 2500 },
            provider: "RAZORPAY",
            providerRef: "order-1",
            customQuoteRevisionId: null
          }]
        }
      }] as never)
      .mockResolvedValueOnce([]);
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(true);
    txMock.booking.updateMany.mockResolvedValue({ count: 1 });
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });

    await processMaintenancePlanOccurrences(now);

    expect(isPaymentOrderSafeToAbandon).toHaveBeenCalledWith({
      userId: "customer-1",
      bookingId: "booking-1",
      razorpayOrderId: "order-1"
    });

    expect(txMock.booking.updateMany).toHaveBeenCalledWith({
      where: { id: "booking-1", status: BookingStatus.PENDING },
      data: {
        status: BookingStatus.CANCELLED_MANUAL,
        clientRequestKey: null,
        clientRequestHash: null
      }
    });
    expect(txMock.payment.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ id: "payment-1", status: PaymentStatus.PENDING }),
      data: expect.objectContaining({ status: PaymentStatus.FAILED })
    }));
    expect(txMock.walletTransaction.findFirst).toHaveBeenCalledWith({
      where: {
        userId: "customer-1",
        type: "WALLET_CREDIT",
        OR: [
          { referenceId: "payment-1" },
          { metadata: { path: ["paymentId"], equals: "payment-1" } },
          {
            referenceId: "booking-1",
            referenceType: { in: ["PAYMENT_ORDER_FAILED", "ABANDONED_PAYMENT"] }
          }
        ]
      },
      select: { id: true }
    });
    expect(txMock.user.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "customer-1" }
    }));
    expect(txMock.user.update.mock.calls[0][0].data.walletBalance.increment.toString())
      .toBe("25");
    expect(txMock.walletTransaction.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        type: "WALLET_CREDIT",
        amount: expect.anything(),
        referenceType: "ABANDONED_PAYMENT",
        referenceId: "payment-1"
      })
    }));
    expect(txMock.walletTransaction.create.mock.calls[0][0].data.amount.toString())
      .toBe("25");
    expect(txMock.maintenanceOccurrence.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        bookingId: null,
        status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION,
        failureReason: "Payment checkout was abandoned"
      })
    }));
  });

  it("restores the wallet debit when provider reconciliation already failed the payment", async () => {
    const now = new Date();
    const abandonedAt = new Date(now.getTime() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt: abandonedAt,
          payments: [{
            id: "payment-1",
            status: PaymentStatus.PENDING,
            createdAt: abandonedAt,
            notes: { walletDeductAmountPaise: 2500 },
            provider: "RAZORPAY",
            providerRef: "order-1",
            customQuoteRevisionId: null
          }]
        }
      }] as never)
      .mockResolvedValueOnce([]);
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(true);
    txMock.booking.updateMany.mockResolvedValue({ count: 1 });
    txMock.payment.updateMany.mockResolvedValueOnce({ count: 0 });
    txMock.payment.findUnique.mockResolvedValueOnce({ status: PaymentStatus.FAILED, notes: {} } as never);
    txMock.maintenanceOccurrence.updateMany.mockResolvedValue({ count: 1 });

    await processMaintenancePlanOccurrences(now);

    expect(txMock.payment.findUnique).toHaveBeenCalledWith({
      where: { id: "payment-1" },
      select: { status: true, notes: true }
    });
    expect(txMock.user.update).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: "customer-1" },
      data: { walletBalance: { increment: expect.anything() } }
    }));
    expect(txMock.walletTransaction.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        type: "WALLET_CREDIT",
        referenceType: "ABANDONED_PAYMENT",
        referenceId: "payment-1"
      })
    }));
  });

  it("does not restore a payment wallet debit when another credit references its payment or booking", async () => {
    const abandonedAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany
      .mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt: abandonedAt,
          payments: [{
            id: "payment-1",
            status: PaymentStatus.PENDING,
            createdAt: abandonedAt,
            notes: { walletDeductAmountPaise: 2500 },
            provider: "RAZORPAY",
            providerRef: "order-1",
            customQuoteRevisionId: null
          }]
        }
      }] as never)
      .mockResolvedValueOnce([]);
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(true);
    txMock.walletTransaction.findFirst.mockResolvedValue({ id: "credit-from-other-path" } as never);

    await processMaintenancePlanOccurrences();

    expect(txMock.walletTransaction.findFirst).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({
        type: "WALLET_CREDIT",
        OR: expect.arrayContaining([
          { referenceId: "payment-1" },
          {
            referenceId: "booking-1",
            referenceType: { in: ["PAYMENT_ORDER_FAILED", "ABANDONED_PAYMENT"] }
          }
        ])
      })
    }));
    expect(txMock.user.update).not.toHaveBeenCalled();
    expect(txMock.walletTransaction.create).not.toHaveBeenCalled();
  });

  it.each([PaymentStatus.PENDING, PaymentStatus.AUTHORIZED])(
    "keeps a linked booking while a %s payment may still settle",
    async (paymentStatus) => {
      prismaMock.maintenanceOccurrence.findMany.mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          status: BookingStatus.PENDING,
          createdAt: new Date(Date.now() - 60 * 60 * 1000),
          payments: [{ status: paymentStatus, createdAt: new Date(Date.now() - 60 * 60 * 1000) }]
        }
      }] as never);

      await processMaintenancePlanOccurrences();

      expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
    }
  );

  it.each([PaymentStatus.PENDING, PaymentStatus.FAILED])(
    "keeps an old %s payment linked while Razorpay still reports it unresolved",
    async (paymentStatus) => {
      const createdAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
      prismaMock.maintenanceOccurrence.findMany.mockResolvedValueOnce([{
        id: "occurrence-1",
        planId: "plan-1",
        bookingId: "booking-1",
        plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
        booking: {
          id: "booking-1",
          customerId: "customer-1",
          status: BookingStatus.PENDING,
          createdAt,
          payments: [{
            id: "payment-1",
            status: paymentStatus,
            createdAt,
            notes: {},
            provider: "RAZORPAY",
            providerRef: "order-1",
            customQuoteRevisionId: null
          }]
        }
      }] as never);
      vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(false);

      await processMaintenancePlanOccurrences();

      expect(isPaymentOrderSafeToAbandon).toHaveBeenCalledOnce();
      expect(txMock.booking.updateMany).not.toHaveBeenCalled();
      expect(txMock.payment.updateMany).not.toHaveBeenCalled();
      expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
    }
  );

  it("keeps a maintenance booking linked when reconciliation finds a late capture", async () => {
    const createdAt = new Date(Date.now() - 25 * 60 * 60 * 1000);
    prismaMock.maintenanceOccurrence.findMany.mockResolvedValueOnce([{
      id: "occurrence-1",
      planId: "plan-1",
      bookingId: "booking-1",
      plan: { id: "plan-1", customerId: "customer-1", status: MaintenancePlanStatus.ACTIVE },
      booking: {
        id: "booking-1",
        customerId: "customer-1",
        status: BookingStatus.PENDING,
        createdAt,
        payments: [{
          id: "payment-1",
          status: PaymentStatus.FAILED,
          createdAt,
          notes: {},
          provider: "RAZORPAY",
          providerRef: "order-1",
          customQuoteRevisionId: null
        }]
      }
    }] as never);
    vi.mocked(isPaymentOrderSafeToAbandon).mockResolvedValue(false);

    await processMaintenancePlanOccurrences();

    expect(txMock.booking.updateMany).not.toHaveBeenCalled();
    expect(txMock.payment.updateMany).not.toHaveBeenCalled();
    expect(txMock.maintenanceOccurrence.updateMany).not.toHaveBeenCalled();
  });
});
