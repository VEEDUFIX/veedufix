import cron from "node-cron";
import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { publishNotificationEvent } from "../../lib/realtime.js";
import type { OpsAlertKind } from "../ops/ops.service.js";

type AlertState = {
  sourceId: string;
  kind: OpsAlertKind;
  title: string;
  message: string;
  bookingId?: string | null;
  severity: "low" | "medium" | "high" | "critical";
  metadata: Prisma.InputJsonValue;
};

type SyncResult = {
  scanned: number;
  opened: number;
  resolved: number;
};

const SUPPORT_ALERT_PREFIX = "support-sla:";
const DISPUTE_ALERT_PREFIX = "dispute-sla:";
const PAYOUT_ALERT_PREFIX = "payout-sla:";
const REFUND_ALERT_PREFIX = "refund-sla:";

const SUPPORT_WARN_MS = 2 * 60 * 60 * 1000;
const SUPPORT_HIGH_MS = 8 * 60 * 60 * 1000;
const SUPPORT_CRITICAL_MS = 24 * 60 * 60 * 1000;

const DISPUTE_WARN_MS = 24 * 60 * 60 * 1000;
const DISPUTE_HIGH_MS = 36 * 60 * 60 * 1000;
const DISPUTE_CRITICAL_MS = 48 * 60 * 60 * 1000;

const FINANCE_WARN_MS = 30 * 60 * 1000;
const FINANCE_HIGH_MS = 2 * 60 * 60 * 1000;
const FINANCE_CRITICAL_MS = 6 * 60 * 60 * 1000;

let opsExceptionSweeperStarted = false;

function hoursSince(date: Date): number {
  return Math.max(0, (Date.now() - date.getTime()) / (60 * 60 * 1000));
}

function minutesSince(date: Date): number {
  return Math.max(0, (Date.now() - date.getTime()) / 60000);
}

function formatAge(hours: number): string {
  if (hours < 1) {
    return `${Math.max(1, Math.round(hours * 60))}m`;
  }

  if (hours < 24) {
    return `${Math.round(hours)}h`;
  }

  return `${Math.floor(hours / 24)}d`;
}

function severityForAge(ageMs: number, warnMs: number, highMs: number, criticalMs: number) {
  if (ageMs < warnMs) {
    return null;
  }

  if (ageMs >= criticalMs) {
    return "critical" as const;
  }

  if (ageMs >= highMs) {
    return "high" as const;
  }

  return "medium" as const;
}

function stringifyJson(value: Prisma.JsonValue | Prisma.InputJsonValue): string {
  return JSON.stringify(value);
}

async function notifyAdmins(title: string, body: string, data: Record<string, unknown>): Promise<void> {
  const admins = await prisma.user.findMany({
    where: { role: "ADMIN", isActive: true },
    select: { id: true }
  });

  await Promise.all(
    admins.map((admin) =>
      publishNotificationEvent({
        userId: admin.id,
        title,
        body,
        type: "ops_alert",
        data
      })
    )
  );
}

async function syncAlert(desired: AlertState | null): Promise<boolean> {
  const existing = desired ? await prisma.opsAlert.findUnique({ where: { sourceId: desired.sourceId } }) : null;

  if (!desired) {
    if (existing && existing.status !== "resolved") {
      await prisma.opsAlert.update({
        where: { sourceId: existing.sourceId },
        data: { status: "resolved" }
      });
      return true;
    }

    return false;
  }

  const metadata = desired.metadata;
  const message = desired.message;
  const shouldNotify =
    !existing ||
    existing.status === "resolved" ||
    existing.severity !== desired.severity ||
    existing.message !== message ||
    stringifyJson(existing.metadata ?? {}) !== stringifyJson(metadata);

  if (!existing) {
    await prisma.opsAlert.create({
      data: {
        sourceId: desired.sourceId,
        type: desired.kind,
        bookingId: desired.bookingId ?? null,
        message,
        metadata,
        severity: desired.severity,
        status: "open"
      }
    });
  } else {
    await prisma.opsAlert.update({
      where: { sourceId: existing.sourceId },
      data: {
        type: desired.kind,
        bookingId: desired.bookingId ?? null,
        message,
        metadata,
        severity: desired.severity,
        status: "open"
      }
    });
  }

  if (shouldNotify) {
    await notifyAdmins(desired.title, message, {
      sourceId: desired.sourceId,
      kind: desired.kind,
      bookingId: desired.bookingId ?? null,
      severity: desired.severity,
      ...metadata
    });
  }

  return true;
}

async function resolveMissingAlerts(prefix: string, activeSourceIds: Set<string>): Promise<number> {
  const existing = await prisma.opsAlert.findMany({
    where: {
      sourceId: {
        startsWith: prefix
      },
      status: {
        not: "resolved"
      }
    },
    select: {
      sourceId: true
    }
  });

  let resolved = 0;
  for (const alert of existing) {
    if (activeSourceIds.has(alert.sourceId)) {
      continue;
    }

    await prisma.opsAlert.update({
      where: { sourceId: alert.sourceId },
      data: { status: "resolved" }
    });
    resolved += 1;
  }

  return resolved;
}

async function sweepSupportTickets(): Promise<SyncResult> {
  const tickets = await prisma.supportTicket.findMany({
    where: {
      status: {
        in: ["OPEN", "IN_PROGRESS"]
      }
    },
    select: {
      id: true,
      subject: true,
      message: true,
      status: true,
      createdAt: true,
      updatedAt: true,
      user: {
        select: {
          name: true
        }
      }
    },
    orderBy: {
      updatedAt: "asc"
    },
    take: 200
  });

  const activeSourceIds = new Set<string>();
  let opened = 0;

  for (const ticket of tickets) {
    const ageMs = Date.now() - ticket.updatedAt.getTime();
    const severity = severityForAge(ageMs, SUPPORT_WARN_MS, SUPPORT_HIGH_MS, SUPPORT_CRITICAL_MS);
    if (!severity) {
      continue;
    }

    const sourceId = `${SUPPORT_ALERT_PREFIX}${ticket.id}`;
    activeSourceIds.add(sourceId);
    const ageHours = hoursSince(ticket.updatedAt);

    const state: AlertState = {
      sourceId,
      kind: "support_escalation",
      title: `Support ticket needs attention`,
      message: `${ticket.subject} has been waiting ${formatAge(ageHours)} and is still ${ticket.status.toLowerCase().replaceAll("_", " ")}.`,
      bookingId: null,
      severity,
      metadata: {
        title: `Support ticket SLA - ${ticket.subject}`,
        ticketId: ticket.id,
        ticketStatus: ticket.status,
        customerName: ticket.user.name,
        ageHours,
        sourceLabel: "support_ticket"
      }
    };

    if (await syncAlert(state)) {
      opened += 1;
    }
  }

  const resolved = await resolveMissingAlerts(SUPPORT_ALERT_PREFIX, activeSourceIds);
  return { scanned: tickets.length, opened, resolved };
}

async function sweepDisputes(): Promise<SyncResult> {
  const disputes = await prisma.dispute.findMany({
    where: {
      status: {
        in: ["open", "under_review"]
      }
    },
    select: {
      id: true,
      bookingId: true,
      reason: true,
      status: true,
      createdAt: true,
      booking: {
        select: {
          code: true,
          customer: {
            select: {
              name: true
            }
          }
        }
      }
    },
    orderBy: {
      createdAt: "asc"
    },
    take: 200
  });

  const activeSourceIds = new Set<string>();
  let opened = 0;

  for (const dispute of disputes) {
    const ageMs = Date.now() - dispute.createdAt.getTime();
    const severity = severityForAge(ageMs, DISPUTE_WARN_MS, DISPUTE_HIGH_MS, DISPUTE_CRITICAL_MS);
    if (!severity) {
      continue;
    }

    const sourceId = `${DISPUTE_ALERT_PREFIX}${dispute.id}`;
    activeSourceIds.add(sourceId);
    const ageHours = hoursSince(dispute.createdAt);

    const state: AlertState = {
      sourceId,
      kind: "dispute_escalation",
      title: `Dispute SLA exceeded`,
      message: `Dispute on booking ${dispute.booking.code} has been open for ${formatAge(ageHours)} and requires review.`,
      bookingId: dispute.bookingId,
      severity,
      metadata: {
        title: `Dispute SLA - ${dispute.booking.code}`,
        disputeId: dispute.id,
        bookingCode: dispute.booking.code,
        customerName: dispute.booking.customer.name,
        reason: dispute.reason,
        disputeStatus: dispute.status,
        ageHours,
        sourceLabel: "dispute"
      }
    };

    if (await syncAlert(state)) {
      opened += 1;
    }
  }

  const resolved = await resolveMissingAlerts(DISPUTE_ALERT_PREFIX, activeSourceIds);
  return { scanned: disputes.length, opened, resolved };
}

async function sweepPayouts(): Promise<SyncResult> {
  const payouts = await prisma.payout.findMany({
    where: {
      status: "failed"
    },
    select: {
      id: true,
      bookingId: true,
      amount: true,
      failureReason: true,
      createdAt: true,
      updatedAt: true,
      booking: {
        select: {
          code: true,
          customer: {
            select: {
              name: true
            }
          }
        }
      }
    },
    orderBy: {
      updatedAt: "asc"
    },
    take: 200
  });

  const activeSourceIds = new Set<string>();
  let opened = 0;

  for (const payout of payouts) {
    const ageMs = Date.now() - payout.updatedAt.getTime();
    const severity = severityForAge(ageMs, FINANCE_WARN_MS, FINANCE_HIGH_MS, FINANCE_CRITICAL_MS);
    if (!severity) {
      continue;
    }

    const sourceId = `${PAYOUT_ALERT_PREFIX}${payout.id}`;
    activeSourceIds.add(sourceId);
    const ageHours = hoursSince(payout.updatedAt);

    const state: AlertState = {
      sourceId,
      kind: "payout_failure",
      title: `Worker payout failed`,
      message: `Payout for booking ${payout.booking.code} has been failing for ${formatAge(ageHours)}${payout.failureReason ? `: ${payout.failureReason}` : "."}`,
      bookingId: payout.bookingId,
      severity,
      metadata: {
        title: `Payout failure - ${payout.booking.code}`,
        payoutId: payout.id,
        bookingCode: payout.booking.code,
        customerName: payout.booking.customer.name,
        amount: payout.amount,
        failureReason: payout.failureReason,
        ageHours,
        sourceLabel: "payout"
      }
    };

    if (await syncAlert(state)) {
      opened += 1;
    }
  }

  const resolved = await resolveMissingAlerts(PAYOUT_ALERT_PREFIX, activeSourceIds);
  return { scanned: payouts.length, opened, resolved };
}

async function sweepRefunds(): Promise<SyncResult> {
  const refunds = await prisma.refund.findMany({
    where: {
      status: "failed"
    },
    select: {
      id: true,
      bookingId: true,
      amount: true,
      reason: true,
      failureReason: true,
      createdAt: true,
      updatedAt: true,
      booking: {
        select: {
          code: true,
          customer: {
            select: {
              name: true
            }
          }
        }
      }
    },
    orderBy: {
      updatedAt: "asc"
    },
    take: 200
  });

  const activeSourceIds = new Set<string>();
  let opened = 0;

  for (const refund of refunds) {
    const ageMs = Date.now() - refund.updatedAt.getTime();
    const severity = severityForAge(ageMs, FINANCE_WARN_MS, FINANCE_HIGH_MS, FINANCE_CRITICAL_MS);
    if (!severity) {
      continue;
    }

    const sourceId = `${REFUND_ALERT_PREFIX}${refund.id}`;
    activeSourceIds.add(sourceId);
    const ageHours = hoursSince(refund.updatedAt);

    const state: AlertState = {
      sourceId,
      kind: "refund_failure",
      title: `Customer refund failed`,
      message: `Refund for booking ${refund.booking.code} has been failing for ${formatAge(ageHours)}${refund.failureReason ? `: ${refund.failureReason}` : "."}`,
      bookingId: refund.bookingId,
      severity,
      metadata: {
        title: `Refund failure - ${refund.booking.code}`,
        refundId: refund.id,
        bookingCode: refund.booking.code,
        customerName: refund.booking.customer.name,
        amount: refund.amount,
        failureReason: refund.failureReason,
        reason: refund.reason,
        ageHours,
        sourceLabel: "refund"
      }
    };

    if (await syncAlert(state)) {
      opened += 1;
    }
  }

  const resolved = await resolveMissingAlerts(REFUND_ALERT_PREFIX, activeSourceIds);
  return { scanned: refunds.length, opened, resolved };
}

export async function sweepOpsExceptions(): Promise<{
  support: SyncResult;
  disputes: SyncResult;
  payouts: SyncResult;
  refunds: SyncResult;
}> {
  const [support, disputes, payouts, refunds] = await Promise.all([
    sweepSupportTickets(),
    sweepDisputes(),
    sweepPayouts(),
    sweepRefunds()
  ]);

  return { support, disputes, payouts, refunds };
}

export function startOpsExceptionSweep(): void {
  if (opsExceptionSweeperStarted) {
    return;
  }

  opsExceptionSweeperStarted = true;

  void sweepOpsExceptions().catch((error) => {
    logger.error({ error }, "Initial ops exception sweep failed");
  });

  cron.schedule("*/15 * * * *", () => {
    void sweepOpsExceptions().catch((error) => {
      logger.error({ error }, "Ops exception sweep cron run failed");
    });
  });

  logger.info("Ops exception sweep cron started");
}
