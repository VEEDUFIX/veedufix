import { BookingStatus, MaintenanceOccurrenceStatus, MaintenancePlanStatus, PaymentStatus, Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { logger } from "../../lib/logger.js";
import { serviceAvailabilityWhere, variantAvailabilityWhere } from "../catalog/availability-inheritance.js";
import { sendToRecipient } from "../scheduler/lifecycle-notifications.js";
import { isPaymentOrderSafeToAbandon } from "../payments/payments.service.js";

const PLAN_INCLUDE = {
  service: { select: { id: true, name: true, startingPrice: true, maintenanceReminderHours: true } },
  variant: { select: { id: true, name: true, price: true } },
  address: { select: { id: true, label: true, pincode: true, line1: true, city: { select: { id: true, name: true } } } },
  occurrences: {
    orderBy: [{ dueAt: "asc" as const }, { sequence: "asc" as const }],
    include: { booking: { select: { id: true, code: true, status: true, totalAmount: true } } }
  },
  events: { orderBy: { createdAt: "desc" as const } }
};

const PENDING_BOOKING_GRACE_MS = 30 * 60 * 1000;
const ABANDONED_PAYMENT_GRACE_MS = 24 * 60 * 60 * 1000;

type Tx = Prisma.TransactionClient;

function utcDate(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function parseDate(value: string): Date {
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw AppError.badRequest("Enter a valid calendar date");
  }
  return date;
}

function isValidTimezone(timezone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: timezone });
    return true;
  } catch {
    return false;
  }
}

export function calendarDateInTimezone(date: Date, timezone: string): Date {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(date);
  const value = (type: string) => Number(parts.find((part) => part.type === type)?.value);
  return new Date(Date.UTC(value("year"), value("month") - 1, value("day")));
}

export function localDateTimeToUtc(date: Date, time: string, timezone: string): Date | null {
  if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(time) || !isValidTimezone(timezone)) return null;
  const [hour, minute] = time.split(":").map(Number);
  const requestedWallTime = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), hour, minute);
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23"
  });

  for (let shiftMinutes = 0; shiftMinutes <= 180; shiftMinutes += 1) {
    const targetWallTime = requestedWallTime + shiftMinutes * 60 * 1000;
    let candidate = targetWallTime;
    for (let attempt = 0; attempt < 4; attempt += 1) {
      const parts = formatter.formatToParts(new Date(candidate));
      const value = (type: string) => Number(parts.find((part) => part.type === type)?.value);
      const representedWallTime = Date.UTC(
        value("year"), value("month") - 1, value("day"), value("hour"), value("minute")
      );
      const correction = targetWallTime - representedWallTime;
      if (correction === 0) return new Date(candidate);
      candidate += correction;
    }
  }
  // Move a missing spring-transition clock time to the first valid local minute.
  return null;
}

/** Add months while anchoring to the original day so Jan 31 -> Feb 28 -> Mar 31. */
export function addMonthsUtc(date: Date, months: number): Date {
  const monthIndex = date.getUTCMonth() + months;
  const year = date.getUTCFullYear() + Math.floor(monthIndex / 12);
  const month = ((monthIndex % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(date.getUTCDate(), lastDay)));
}

function occurrenceDate(startAt: Date, intervalMonths: number, sequence: number): Date {
  const monthIndex = startAt.getUTCMonth() + intervalMonths * (sequence - 1);
  const year = startAt.getUTCFullYear() + Math.floor(monthIndex / 12);
  const month = ((monthIndex % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
  return new Date(Date.UTC(year, month, Math.min(startAt.getUTCDate(), lastDay)));
}

async function getPlanForCustomer(customerId: string, planId: string) {
  const plan = await prisma.maintenancePlan.findFirst({
    where: { id: planId, customerId },
    include: PLAN_INCLUDE
  });
  if (!plan) throw AppError.notFound("Maintenance plan not found");
  return plan;
}

export async function createCustomerMaintenancePlan(
  customerId: string,
  input: {
    serviceId: string;
    variantId?: string;
    addressId: string;
    intervalMonths: number;
    startAt: string;
    endAt?: string;
    preferredTime?: string;
    timezone: string;
  }
) {
  const startAt = parseDate(input.startAt);
  const endAt = input.endAt ? parseDate(input.endAt) : null;
  if (!isValidTimezone(input.timezone)) throw AppError.badRequest("Choose a valid time zone");
  if (input.preferredTime && !/^([01]\d|2[0-3]):[0-5]\d$/.test(input.preferredTime)) {
    throw AppError.badRequest("Choose a valid preferred visit time");
  }
  if (startAt < calendarDateInTimezone(new Date(), input.timezone)) throw AppError.badRequest("The first maintenance visit must be today or later");
  if (endAt && endAt < startAt) throw AppError.badRequest("The plan end date must be after its start date");

  // The customer-facing address picker submits SavedAddress IDs. Resolve through
  // the same canonical booking address path used by checkout before persisting it.
  const { resolveCustomerContext } = await import("../payments/payments.service.js");
  const customerContext = await resolveCustomerContext(customerId, undefined, input.addressId);
  const service = await prisma.service.findFirst({
    where: {
      id: input.serviceId,
      isActive: true,
      bookingEnabled: true,
      maintenanceEnabled: true,
      publicationStatus: "PUBLISHED",
      maintenanceIntervalsMonths: { has: input.intervalMonths },
      AND: [serviceAvailabilityWhere(customerContext.serviceAreaIds)]
    },
    select: { id: true }
  });
  if (!service) throw AppError.badRequest("This service is not available for recurring maintenance at this address");
  if (input.variantId) {
    const variant = await prisma.serviceVariant.findFirst({
      where: {
        id: input.variantId,
        serviceId: service.id,
        isAvailable: true,
        AND: [variantAvailabilityWhere(customerContext.serviceAreaIds)]
      },
      select: { id: true }
    });
    if (!variant) throw AppError.badRequest("The selected option is not available at this address");
  } else {
    const activeVariant = await prisma.serviceVariant.findFirst({
      where: { serviceId: service.id, isAvailable: true },
      select: { id: true }
    });
    if (activeVariant) {
      const availableVariant = await prisma.serviceVariant.findFirst({
        where: {
          serviceId: service.id,
          isAvailable: true,
          AND: [variantAvailabilityWhere(customerContext.serviceAreaIds)]
        },
        select: { id: true }
      });
      if (!availableVariant) {
        throw AppError.badRequest("No service option is available at this address");
      }
      throw AppError.badRequest("Choose a service option for this maintenance plan");
    }
  }

  return prisma.$transaction(async (tx) => {
    const plan = await tx.maintenancePlan.create({
      data: {
        customerId,
        serviceId: service.id,
        variantId: input.variantId,
        addressId: customerContext.addressId,
        intervalMonths: input.intervalMonths,
        preferredTime: input.preferredTime,
        timezone: input.timezone,
        startAt,
        endAt,
        nextDueAt: startAt,
        nextSequence: 1,
        confirmationRequired: true,
        status: MaintenancePlanStatus.ACTIVE
      }
    });
    await tx.maintenancePlanEvent.create({
      data: {
        planId: plan.id,
        actorId: customerId,
        action: "PLAN_CREATED",
        details: { serviceId: service.id, intervalMonths: input.intervalMonths, startAt: startAt.toISOString() }
      }
    });
    const firstDueAt = occurrenceDate(startAt, input.intervalMonths, 1);
    if (!endAt || firstDueAt <= endAt) {
      await tx.maintenanceOccurrence.create({
        data: { planId: plan.id, sequence: 1, dueAt: firstDueAt }
      });
      await tx.maintenancePlan.update({
        where: { id: plan.id },
        data: { nextSequence: 2, nextDueAt: occurrenceDate(startAt, input.intervalMonths, 2) }
      });
    }
    return tx.maintenancePlan.findUniqueOrThrow({ where: { id: plan.id }, include: PLAN_INCLUDE });
  });
}

export async function listCustomerMaintenancePlans(customerId: string) {
  return prisma.maintenancePlan.findMany({
    where: { customerId },
    include: PLAN_INCLUDE,
    orderBy: [{ updatedAt: "desc" }]
  });
}

export async function listAdminMaintenancePlans(input: { status?: string; serviceId?: string }) {
  return prisma.maintenancePlan.findMany({
    where: {
      ...(input.status ? { status: input.status as MaintenancePlanStatus } : {}),
      ...(input.serviceId ? { serviceId: input.serviceId } : {})
    },
    include: {
      ...PLAN_INCLUDE,
      customer: { select: { id: true, name: true, phone: true } }
    },
    orderBy: [{ updatedAt: "desc" }],
    take: 200
  });
}

export async function updateCustomerMaintenancePlan(
  customerId: string,
  planId: string,
  action: "pause" | "resume" | "cancel"
) {
  const current = await getPlanForCustomer(customerId, planId);
  const from = current.status;
  const to = action === "pause" ? MaintenancePlanStatus.PAUSED
    : action === "resume" ? MaintenancePlanStatus.ACTIVE
    : MaintenancePlanStatus.CANCELLED;
  const allowed = action === "pause" ? from === MaintenancePlanStatus.ACTIVE
    : action === "resume" ? from === MaintenancePlanStatus.PAUSED
    : from !== MaintenancePlanStatus.CANCELLED;
  if (!allowed) throw AppError.conflict("Maintenance plan status changed. Refresh and try again.");

  return prisma.$transaction(async (tx) => {
    const changed = await tx.maintenancePlan.updateMany({
      where: { id: planId, customerId, status: from },
      data: { status: to }
    });
    if (changed.count !== 1) throw AppError.conflict("Maintenance plan status changed. Refresh and try again.");
    if (action === "cancel") {
      await tx.maintenanceOccurrence.updateMany({
        where: { planId, status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION, bookingId: null },
        data: { status: MaintenanceOccurrenceStatus.CANCELLED, respondedAt: new Date() }
      });
    }
    await tx.maintenancePlanEvent.create({
      data: { planId, actorId: customerId, action: action === "cancel" ? "PLAN_CANCELLED" : `PLAN_${action.toUpperCase()}D`, details: { previousStatus: from, status: to } }
    });
    return tx.maintenancePlan.findUniqueOrThrow({ where: { id: planId }, include: PLAN_INCLUDE });
  });
}

export async function updateCustomerMaintenanceOccurrence(input: {
  customerId: string;
  planId: string;
  occurrenceId: string;
  action: "skip" | "reschedule";
  dueAt?: string;
}) {
  const plan = await getPlanForCustomer(input.customerId, input.planId);
  const occurrence = plan.occurrences.find((item: { id: string }) => item.id === input.occurrenceId);
  if (!occurrence) throw AppError.notFound("Maintenance visit not found");
  if (occurrence.status !== MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION || occurrence.bookingId) {
    throw AppError.conflict("This maintenance visit can no longer be changed");
  }
  let nextDueAt: Date | undefined;
  if (input.action === "reschedule") {
    if (!input.dueAt) throw AppError.badRequest("Choose a new visit date");
    nextDueAt = parseDate(input.dueAt);
    if (!isValidTimezone(plan.timezone)) throw AppError.badRequest("The plan has an invalid time zone; contact support before rescheduling");
    if (nextDueAt < calendarDateInTimezone(new Date(), plan.timezone)) throw AppError.badRequest("Choose today or a future date");
    if (plan.endAt && nextDueAt > plan.endAt) throw AppError.badRequest("The new date is outside this plan");
  }
  return prisma.$transaction(async (tx) => {
    const changed = await tx.maintenanceOccurrence.updateMany({
      where: {
        id: input.occurrenceId,
        planId: input.planId,
        status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION,
        bookingId: null
      },
      data: input.action === "skip"
        ? { status: MaintenanceOccurrenceStatus.SKIPPED, respondedAt: new Date() }
        : { dueAt: nextDueAt!, reminderSentAt: null, failureReason: null, respondedAt: new Date() }
    });
    if (changed.count !== 1) throw AppError.conflict("This maintenance visit changed. Refresh and try again.");
    await tx.maintenancePlanEvent.create({
      data: {
        planId: input.planId,
        actorId: input.customerId,
        action: input.action === "skip" ? "OCCURRENCE_SKIPPED" : "OCCURRENCE_RESCHEDULED",
        details: { occurrenceId: input.occurrenceId, dueAt: nextDueAt?.toISOString() ?? null }
      }
    });
    return tx.maintenancePlan.findUniqueOrThrow({ where: { id: input.planId }, include: PLAN_INCLUDE });
  });
}

export async function confirmOccurrenceBookingLink(input: {
  tx: Tx;
  customerId: string;
  occurrenceId: string;
  serviceId: string;
  variantId?: string;
  addressId: string;
  bookingId: string;
  scheduledFor: Date;
}): Promise<void> {
  const occurrence = await input.tx.maintenanceOccurrence.findFirst({
    where: {
      id: input.occurrenceId,
      plan: {
        customerId: input.customerId,
        serviceId: input.serviceId,
        variantId: input.variantId ?? null,
        addressId: input.addressId,
        status: MaintenancePlanStatus.ACTIVE
      },
      status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION,
      bookingId: null
    },
    select: { id: true, planId: true, dueAt: true, plan: { select: { timezone: true } } }
  });
  if (!occurrence) throw AppError.conflict("This maintenance visit is no longer available");
  if (
    calendarDateInTimezone(input.scheduledFor, occurrence.plan.timezone).getTime() !==
    utcDate(occurrence.dueAt).getTime()
  ) {
    throw AppError.badRequest("Schedule the booking for the selected maintenance visit");
  }
  const linked = await input.tx.maintenanceOccurrence.updateMany({
    where: { id: occurrence.id, status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION, bookingId: null },
    data: { status: MaintenanceOccurrenceStatus.BOOKING_CREATED, bookingId: input.bookingId, failureReason: null }
  });
  if (linked.count !== 1) throw AppError.conflict("This maintenance visit has already been booked");
  await input.tx.maintenancePlanEvent.create({
    data: {
      planId: occurrence.planId,
      actorId: input.customerId,
      action: "OCCURRENCE_BOOKING_CREATED",
      details: { occurrenceId: occurrence.id, bookingId: input.bookingId }
    }
  });
}

async function generateDueOccurrences(now: Date): Promise<void> {
  const horizon = new Date(now.getTime() + 45 * 24 * 60 * 60 * 1000);
  const plans = await prisma.maintenancePlan.findMany({
    where: {
      status: MaintenancePlanStatus.ACTIVE,
      nextDueAt: { lte: horizon },
      OR: [{ endAt: null }, { endAt: { gte: utcDate(now) } }]
    },
    select: { id: true, startAt: true, endAt: true, nextDueAt: true, nextSequence: true, intervalMonths: true, timezone: true }
  });
  for (const plan of plans) {
    const today = calendarDateInTimezone(now, plan.timezone);
    let sequence = plan.nextSequence;
    let dueAt = occurrenceDate(plan.startAt, plan.intervalMonths, sequence);
    while (dueAt < today) {
      sequence += 1;
      dueAt = occurrenceDate(plan.startAt, plan.intervalMonths, sequence);
    }
    const skippedCount = sequence - plan.nextSequence;
    if (plan.endAt && dueAt > plan.endAt) continue;
    try {
      await prisma.$transaction(async (tx) => {
        const updated = await tx.maintenancePlan.updateMany({
          where: {
            id: plan.id,
            status: MaintenancePlanStatus.ACTIVE,
            nextSequence: plan.nextSequence,
            nextDueAt: plan.nextDueAt
          },
          data: {
            nextSequence: sequence + 1,
            nextDueAt: occurrenceDate(plan.startAt, plan.intervalMonths, sequence + 1)
          }
        });
        if (updated.count !== 1) return;
        if (skippedCount > 0) {
          await tx.maintenancePlanEvent.create({
            data: {
              planId: plan.id,
              action: "MISSED_OCCURRENCES_SKIPPED",
              details: {
                fromSequence: plan.nextSequence,
                throughSequence: sequence - 1,
                count: skippedCount,
                nextDueAt: dueAt.toISOString()
              }
            }
          });
        }
        await tx.maintenanceOccurrence.create({
          data: { planId: plan.id, sequence, dueAt }
        });
        await tx.maintenancePlanEvent.create({
          data: { planId: plan.id, action: "OCCURRENCE_GENERATED", details: { sequence, dueAt: dueAt.toISOString() } }
        });
      });
    } catch (error) {
      logger.warn({ error, planId: plan.id }, "Maintenance occurrence generation failed for plan");
    }
  }
}

async function reconcileLinkedBookings(): Promise<void> {
  const staleBefore = new Date(Date.now() - PENDING_BOOKING_GRACE_MS);
  const abandonedBefore = new Date(Date.now() - ABANDONED_PAYMENT_GRACE_MS);
  const include = {
      plan: { select: { id: true, customerId: true, status: true } },
      booking: {
        select: {
          id: true,
          customerId: true,
          status: true,
          createdAt: true,
          payments: {
            select: {
              id: true,
              status: true,
              createdAt: true,
              notes: true,
              provider: true,
              providerRef: true,
              customQuoteRevisionId: true
            }
          }
        }
      }
  };
  const [cancelledBookings, pendingBookings] = await Promise.all([
    prisma.maintenanceOccurrence.findMany({
      where: {
        status: MaintenanceOccurrenceStatus.BOOKING_CREATED,
        bookingId: { not: null },
        booking: {
          status: {
            in: [
              BookingStatus.CANCELLED,
              BookingStatus.CANCELLED_MANUAL,
              BookingStatus.CANCELLED_NO_SHOW,
              BookingStatus.REFUNDED
            ]
          }
        }
      },
      include,
      orderBy: [{ updatedAt: "asc" }, { id: "asc" }],
      take: 200
    }),
    prisma.maintenanceOccurrence.findMany({
      where: {
        status: MaintenanceOccurrenceStatus.BOOKING_CREATED,
        bookingId: { not: null },
        booking: {
          status: BookingStatus.PENDING,
          OR: [
            { createdAt: { lt: staleBefore }, payments: { none: {} } },
            {
              payments: {
                some: {
                  status: PaymentStatus.PENDING,
                  createdAt: { lt: abandonedBefore }
                },
                every: {
                  OR: [
                    { status: PaymentStatus.FAILED, createdAt: { lt: abandonedBefore } },
                    {
                      status: PaymentStatus.PENDING,
                      createdAt: { lt: abandonedBefore }
                    }
                  ]
                }
              }
            },
            {
              payments: {
                some: {},
                every: { status: PaymentStatus.FAILED, createdAt: { lt: abandonedBefore } }
              }
            }
          ]
        }
      },
      include,
      orderBy: [{ updatedAt: "asc" }, { id: "asc" }],
      take: 200
    })
  ]);
  // Always reconcile cancelled bookings first. A large set of still-payable
  // old Razorpay orders must not monopolize the bounded pending-payment batch.
  const linked = [...cancelledBookings, ...pendingBookings];
  for (const occurrence of linked) {
    const booking = occurrence.booking;
    if (!booking) continue;
    if (booking.status === BookingStatus.PENDING) {
      const abandonedPayments = booking.payments.filter(
        (payment: { status: PaymentStatus; createdAt: Date }) =>
          (payment.status === PaymentStatus.PENDING || payment.status === PaymentStatus.FAILED) &&
          payment.createdAt.getTime() < abandonedBefore.getTime()
      );
      let providerConfirmedAllUncaptured = true;
      for (const payment of abandonedPayments) {
        if (hasPaymentAmountMismatch(payment.notes)) {
          providerConfirmedAllUncaptured = false;
          break;
        }
        if (
          payment.provider !== "RAZORPAY" ||
          !payment.providerRef ||
          payment.customQuoteRevisionId
        ) {
          providerConfirmedAllUncaptured = false;
          break;
        }
        try {
          const safeToAbandon = await isPaymentOrderSafeToAbandon({
            userId: booking.customerId,
            bookingId: booking.id,
            razorpayOrderId: payment.providerRef
          });
          if (!safeToAbandon) {
            providerConfirmedAllUncaptured = false;
            break;
          }
        } catch (error) {
          logger.warn(
            { error, bookingId: booking.id, paymentId: payment.id },
            "Could not confirm abandoned maintenance payment status"
          );
          providerConfirmedAllUncaptured = false;
          break;
        }
      }
      if (abandonedPayments.length > 0 && !providerConfirmedAllUncaptured) continue;
    }
    const cancelled = [
      BookingStatus.CANCELLED,
      BookingStatus.CANCELLED_MANUAL,
      BookingStatus.CANCELLED_NO_SHOW,
      BookingStatus.REFUNDED
    ].includes(booking.status);
    const failed = booking.payments.length > 0 && booking.payments.every(
      (payment: { status: PaymentStatus; createdAt: Date }) =>
        payment.status === PaymentStatus.FAILED && payment.createdAt.getTime() < abandonedBefore.getTime()
    );
    const pendingPayments = booking.payments.filter(
      (payment: { status: PaymentStatus }) => payment.status === PaymentStatus.PENDING
    );
    const pendingAttemptsAreExpired = pendingPayments.length > 0 &&
      booking.payments.every((payment: { status: PaymentStatus; createdAt: Date }) =>
        (payment.status === PaymentStatus.PENDING || payment.status === PaymentStatus.FAILED) &&
        payment.createdAt.getTime() < abandonedBefore.getTime()
      ) &&
      pendingPayments.every((payment: { status: PaymentStatus; createdAt: Date }) =>
        payment.createdAt.getTime() < abandonedBefore.getTime()
      );
    const expiredPending = booking.status === BookingStatus.PENDING &&
      ((booking.createdAt.getTime() < staleBefore.getTime() && booking.payments.length === 0) ||
        pendingAttemptsAreExpired || failed);
    if (!cancelled && !failed && !expiredPending) continue;
    try {
      await prisma.$transaction(async (tx) => {
        if (expiredPending) {
          const cancelledBooking = await tx.booking.updateMany({
            where: { id: booking.id, status: BookingStatus.PENDING },
            data: {
              status: BookingStatus.CANCELLED_MANUAL,
              clientRequestKey: null,
              clientRequestHash: null
            }
          });
          if (cancelledBooking.count !== 1) return;

          for (const payment of booking.payments) {
            if (payment.createdAt.getTime() >= abandonedBefore.getTime()) continue;
            if (payment.status === PaymentStatus.PENDING) {
              const failedPayment = await tx.payment.updateMany({
                where: {
                  id: payment.id,
                  status: PaymentStatus.PENDING,
                  createdAt: { lt: abandonedBefore }
                },
                data: {
                  status: PaymentStatus.FAILED,
                  notes: {
                    ...(payment.notes && typeof payment.notes === "object" && !Array.isArray(payment.notes)
                      ? payment.notes
                      : {}),
                    abandonedAt: new Date().toISOString()
                  } as Prisma.InputJsonValue
                }
              });
              if (failedPayment.count !== 1) {
                // Provider reconciliation may already have marked the payment failed.
                const currentPayment = await tx.payment.findUnique({
                  where: { id: payment.id },
                  select: { status: true, notes: true }
                });
                if (
                  currentPayment?.status !== PaymentStatus.FAILED ||
                  hasPaymentAmountMismatch(currentPayment.notes)
                ) continue;
              }
            } else if (payment.status !== PaymentStatus.FAILED) {
              continue;
            }

            if (hasPaymentAmountMismatch(payment.notes)) continue;

            const walletDebitAmountPaise = readWalletDebitAmountPaise(payment.notes);
            if (walletDebitAmountPaise <= 0) continue;

            const priorWalletCredit = await tx.walletTransaction.findFirst({
              where: {
                userId: booking.customerId,
                type: "WALLET_CREDIT",
                OR: [
                  { referenceId: payment.id },
                  { metadata: { path: ["paymentId"], equals: payment.id } },
                  {
                    referenceId: booking.id,
                    referenceType: { in: ["PAYMENT_ORDER_FAILED", "ABANDONED_PAYMENT"] }
                  }
                ]
              },
              select: { id: true }
            });
            if (priorWalletCredit) continue;

            const walletCreditAmount = new Prisma.Decimal(walletDebitAmountPaise).div(100);
            const updatedCustomer = await tx.user.update({
              where: { id: booking.customerId },
              data: { walletBalance: { increment: walletCreditAmount } },
              select: { walletBalance: true }
            });
            await tx.walletTransaction.create({
              data: {
                userId: booking.customerId,
                type: "WALLET_CREDIT",
                amount: walletCreditAmount,
                referenceType: "ABANDONED_PAYMENT",
                referenceId: payment.id,
                balanceAfter: updatedCustomer.walletBalance,
                metadata: {
                  paymentId: payment.id,
                  note: "Wallet restored after maintenance checkout expired"
                }
              }
            });
          }
        }
        const updated = await tx.maintenanceOccurrence.updateMany({
          where: { id: occurrence.id, bookingId: booking.id, status: MaintenanceOccurrenceStatus.BOOKING_CREATED },
          data: {
            bookingId: null,
            status: occurrence.plan.status === MaintenancePlanStatus.CANCELLED
              ? MaintenanceOccurrenceStatus.CANCELLED
              : MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION,
            failureReason: cancelled
              ? "Linked booking was cancelled"
              : failed
                  ? "Payment failed"
                  : pendingAttemptsAreExpired
                      ? "Payment checkout was abandoned"
                      : "Pending booking expired",
            respondedAt: new Date()
          }
        });
        if (updated.count === 1) {
          await tx.maintenancePlanEvent.create({
            data: {
              planId: occurrence.planId,
              action: cancelled ? "LINKED_BOOKING_CANCELLED" : failed ? "LINKED_BOOKING_PAYMENT_FAILED" : "LINKED_BOOKING_EXPIRED",
              details: { occurrenceId: occurrence.id, bookingId: booking.id }
            }
          });
        }
      });
    } catch (error) {
      logger.warn(
        { error, occurrenceId: occurrence.id, bookingId: booking.id },
        "Maintenance occurrence reconciliation failed"
      );
    }
  }
}

function readWalletDebitAmountPaise(notes: Prisma.JsonValue | null): number {
  if (!notes || typeof notes !== "object" || Array.isArray(notes)) return 0;
  const value = (notes as Prisma.JsonObject).walletDeductAmountPaise;
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0
    ? value
    : 0;
}

function hasPaymentAmountMismatch(notes: Prisma.JsonValue | null): boolean {
  return Boolean(
    notes &&
      typeof notes === "object" &&
      !Array.isArray(notes) &&
      (notes as Record<string, unknown>).amountMismatch === true
  );
}

async function sendOccurrenceReminders(now: Date): Promise<void> {
  const where = {
    status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION,
    bookingId: null,
    reminderSentAt: null,
    dueAt: { gte: new Date(now.getTime() - 24 * 60 * 60 * 1000) },
    plan: { status: MaintenancePlanStatus.ACTIVE }
  };
  const include = {
    plan: {
      select: {
        id: true,
        customerId: true,
        timezone: true,
        preferredTime: true,
        service: { select: { name: true, maintenanceReminderHours: true } }
      }
    }
  };
  let cursorId: string | undefined;
  while (true) {
    const occurrences = await prisma.maintenanceOccurrence.findMany({
      where,
      include,
      orderBy: [{ dueAt: "asc" }, { sequence: "asc" }, { id: "asc" }],
      ...(cursorId ? { cursor: { id: cursorId }, skip: 1 } : {}),
      take: 200
    });
    if (occurrences.length === 0) break;
    cursorId = occurrences[occurrences.length - 1]!.id;

    for (const occurrence of occurrences) {
      if (!isValidTimezone(occurrence.plan.timezone)) continue;
      const visitAt = localDateTimeToUtc(
        occurrence.dueAt,
        occurrence.plan.preferredTime ?? "09:00",
        occurrence.plan.timezone
      );
      if (!visitAt || visitAt.getTime() <= now.getTime()) continue;
      const reminderAt = visitAt.getTime() - occurrence.plan.service.maintenanceReminderHours * 60 * 60 * 1000;
      if (reminderAt > now.getTime()) continue;
      try {
        await sendToRecipient({
          key: `maintenance-occurrence:${occurrence.id}:${occurrence.dueAt.toISOString().slice(0, 10)}:reminder`,
          userId: occurrence.plan.customerId,
          title: "Your maintenance visit is coming up",
          body: `Confirm your ${occurrence.plan.service.name} visit to choose a time and pay securely.`,
          data: { type: "MAINTENANCE_OCCURRENCE", planId: occurrence.planId, occurrenceId: occurrence.id }
        });
        await prisma.maintenanceOccurrence.updateMany({
          where: { id: occurrence.id, status: MaintenanceOccurrenceStatus.AWAITING_CONFIRMATION, reminderSentAt: null },
          data: { reminderSentAt: now }
        });
      } catch {
        // Retry through the idempotent notification key during a later sweep.
      }
    }
    if (occurrences.length < 200) break;
  }
}

export async function processMaintenancePlanOccurrences(now = new Date()): Promise<void> {
  await reconcileLinkedBookings();
  await generateDueOccurrences(now);
  await sendOccurrenceReminders(now);
}
