import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";

export const adminReportsRouter = Router();
adminReportsRouter.use(requireAuth, requireRole("ADMIN"));

function escapeCSV(value: unknown): string {
  const str = String(value ?? "");
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function toCSV(headers: string[], rows: (string | number | null | undefined)[][]): string {
  return [headers.map(escapeCSV).join(","), ...rows.map((r) => r.map(escapeCSV).join(","))].join("\n");
}

// Bookings CSV
adminReportsRouter.get("/bookings", async (_req, response) => {
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
});

// Earnings CSV
adminReportsRouter.get("/earnings", async (_req, response) => {
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
});

// Payouts CSV
adminReportsRouter.get("/payouts", async (_req, response) => {
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
});
