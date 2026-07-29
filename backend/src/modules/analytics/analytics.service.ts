import { prisma } from "../../lib/prisma.js";
import { BookingStatus } from "@prisma/client";
import { subDays, startOfDay, format } from "date-fns";

export type DailyTrendPoint = {
  date: string;
  revenue: number;
  bookings: number;
  newWorkers: number;
};

export async function getAnalyticsTrends(days: number = 30): Promise<DailyTrendPoint[]> {
  const startDate = startOfDay(subDays(new Date(), days - 1));

  // Fetch data
  const bookings = await prisma.booking.findMany({
    where: {
      status: BookingStatus.COMPLETED,
      updatedAt: { gte: startDate } // use updatedAt for revenue/completed bookings
    },
    select: {
      totalAmount: true,
      updatedAt: true
    }
  });

  const newWorkers = await prisma.workerProfile.findMany({
    where: {
      createdAt: { gte: startDate }
    },
    select: {
      createdAt: true
    }
  });

  // Group by date
  const trendsMap = new Map<string, DailyTrendPoint>();

  // Initialize all days with 0
  for (let i = 0; i < days; i++) {
    const d = subDays(new Date(), days - 1 - i);
    const dateStr = format(d, "yyyy-MM-dd");
    trendsMap.set(dateStr, {
      date: dateStr,
      revenue: 0,
      bookings: 0,
      newWorkers: 0,
    });
  }

  // Populate bookings
  for (const b of bookings) {
    const dateStr = format(b.updatedAt, "yyyy-MM-dd");
    const point = trendsMap.get(dateStr);
    if (point) {
      point.bookings += 1;
      point.revenue += Number(b.totalAmount || 0);
    }
  }

  // Populate workers
  for (const w of newWorkers) {
    const dateStr = format(w.createdAt, "yyyy-MM-dd");
    const point = trendsMap.get(dateStr);
    if (point) {
      point.newWorkers += 1;
    }
  }

  return Array.from(trendsMap.values());
}
