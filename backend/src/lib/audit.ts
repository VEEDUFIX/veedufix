import { Prisma } from "@prisma/client";
import { prisma } from "./prisma.js";
import { logger } from "./logger.js";

export type AuditAction =
  | "worker.approved"
  | "worker.rejected"
  | "worker.suspended"
  | "worker.reinstated"
  | "dispute.resolved"
  | "payout.retried"
  | "payout.bulk_retried"
  | "refund.retried"
  | "refund.bulk_retried"
  | "support.ticket_status_updated"
  | "support.ticket_assigned"
  | "support.ticket_replied"
  | "coupon.created"
  | "coupon.updated"
  | "coupon.deleted"
  | "report.exported"
  | "platform.settings_updated"
  | "commission.created"
  | "commission.updated"
  | "commission.deleted"
  | "catalog.category_created"
  | "catalog.category_updated"
  | "catalog.subcategory_created"
  | "catalog.subcategory_updated"
  | "tax_summary.exported";

export type AuditTargetType =
  | "worker_profile"
  | "dispute"
  | "payout"
  | "refund"
  | "support_ticket"
  | "coupon"
  | "report"
  | "platform_settings"
  | "commission_rule"
  | "catalog_category"
  | "catalog_subcategory"
  | "tax_summary";

export async function writeAuditLog({
  adminId,
  action,
  targetType,
  targetId,
  note,
  metadata,
}: {
  adminId: string;
  action: AuditAction;
  targetType: AuditTargetType;
  targetId: string;
  note?: string;
  metadata?: any;
}): Promise<void> {
  try {
    await prisma.adminAuditLog.create({
      data: {
        adminId,
        action,
        targetType,
        targetId,
        note: note ?? null,
        metadata: metadata ?? Prisma.DbNull,
      },
    });
  } catch (error) {
    // Never let audit logging crash a real action
    logger.error({ error, adminId, action, targetId }, "Audit log write failed");
  }
}
