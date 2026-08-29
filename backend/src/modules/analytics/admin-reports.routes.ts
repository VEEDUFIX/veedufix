import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";
import { logger } from "../../lib/logger.js";
import { writeAuditLog } from "../../lib/audit.js";
import type { AuthenticatedRequest } from "../../middleware/auth.js";

export const adminReportsRouter = Router();
adminReportsRouter.use(requireAuth, requireRole("ADMIN"));

function escapeCSV(value: unknown): string {
  const str = String(value ?? "");
  const safeStr = /^[=+\-@]/.test(str) ? `'${str}` : str;
  if (safeStr.includes(",") || safeStr.includes('"') || safeStr.includes("\n")) {
    return `"${safeStr.replace(/"/g, '""')}"`;
  }
  return safeStr;
}

function toCSV(headers: string[], rows: (string | number | null | undefined)[][]): string {
  return [headers.map(escapeCSV).join(","), ...rows.map((r) => r.map(escapeCSV).join(","))].join("\n");
}

// Bookings CSV
adminReportsRouter.get("/bookings", async (request: AuthenticatedRequest, response) => {
  try {
    const bookings = await prisma.booking.findMany({
      include: {
        customer: { select: { name: true, phone: true } },
        worker: { select: { fullName: true } },
        services: { include: { service: { select: { name: true } } }, take: 1 }
      },
      orderBy: { createdAt: "desc" },
      take: 10000
    });

    const csv = toCSV(
      ["Booking Code", "Status", "Customer", "Phone", "Worker", "Service", "Scheduled At", "Total (INR)", "Created At"],
      bookings.map((b) => [
        b.code,
        b.status,
        b.customer.name,
        b.customer.phone ?? "",
        b.worker?.fullName ?? "",
        b.services[0]?.service?.name ?? "",
        b.scheduledAt.toISOString(),
        Number(b.totalAmount),
        b.createdAt.toISOString()
      ])
    );

    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename=bookings_${Date.now()}.csv`);
    response.status(200).send(csv);
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: "report.exported",
      targetType: "report",
      targetId: "bookings",
      note: "Bookings CSV export",
      metadata: { report: "bookings", rows: bookings.length }
    });
  } catch (error) {
    logger.error({ error }, "Failed to export bookings CSV");
    response.status(500).json({ message: "Internal server error" });
  }
});

// Earnings CSV
adminReportsRouter.get("/earnings", async (request: AuthenticatedRequest, response) => {
  try {
    const txs = await prisma.walletTransaction.findMany({
      where: { type: "CREDIT" },
      include: {
        worker: { select: { fullName: true, user: { select: { phone: true } } } }
      },
      orderBy: { createdAt: "desc" },
      take: 10000
    });

    const csv = toCSV(
      ["ID", "Worker", "Phone", "Amount (INR)", "Balance After (INR)", "Date"],
      txs.map((t) => [
        t.id,
        t.worker?.fullName ?? "",
        t.worker?.user?.phone ?? "",
        Number(t.amount),
        Number(t.balanceAfter),
        t.createdAt.toISOString()
      ])
    );

    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename=earnings_${Date.now()}.csv`);
    response.status(200).send(csv);
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: "report.exported",
      targetType: "report",
      targetId: "earnings",
      note: "Earnings CSV export",
      metadata: { report: "earnings", rows: txs.length }
    });
  } catch (error) {
    logger.error({ error }, "Failed to export earnings CSV");
    response.status(500).json({ message: "Internal server error" });
  }
});

// Payouts CSV
adminReportsRouter.get("/payouts", async (request: AuthenticatedRequest, response) => {
  try {
    const payouts = await prisma.walletTransaction.findMany({
      where: { type: "PAYOUT_PENDING" },
      include: {
        worker: { select: { fullName: true, user: { select: { phone: true } } } }
      },
      orderBy: { createdAt: "desc" },
      take: 10000
    });

    const rows: (string | number | null | undefined)[][] = payouts.map((t) => {
      const metadata = t.metadata;
      const upiId =
        metadata && typeof metadata === "object" && !Array.isArray(metadata)
          ? String((metadata as Record<string, unknown>).upiId ?? "")
          : "";

      return [
        t.id,
        t.worker?.fullName ?? "",
        t.worker?.user?.phone ?? "",
        Math.abs(Number(t.amount)),
        upiId,
        t.createdAt.toISOString()
      ];
    });

    const csv = toCSV(["ID", "Worker", "Phone", "Amount (INR)", "UPI ID", "Requested At"], rows);

    response.setHeader("Content-Type", "text/csv");
    response.setHeader("Content-Disposition", `attachment; filename=payouts_${Date.now()}.csv`);
    response.status(200).send(csv);
    void writeAuditLog({
      adminId: request.auth!.userId,
      action: "report.exported",
      targetType: "report",
      targetId: "payouts",
      note: "Payouts CSV export",
      metadata: { report: "payouts", rows: payouts.length }
    });
  } catch (error) {
    logger.error({ error }, "Failed to export payouts CSV");
    response.status(500).json({ message: "Internal server error" });
  }
});
