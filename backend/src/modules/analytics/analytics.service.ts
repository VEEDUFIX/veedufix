import { prisma } from "../../lib/prisma.js";
import { BookingStatus } from "@prisma/client";
import { subDays, startOfDay, format } from "date-fns";

export type DailyTrendPoint = {
  date: string;
  revenue: number;
  bookings: number;
  newWorkers: number;
};

export type AnalyticsBreakdownItem = {
  label: string;
  bookings: number;
  revenue: number;
};

export type AnalyticsInsights = {
  byCity: AnalyticsBreakdownItem[];
  byCategory: AnalyticsBreakdownItem[];
};

export async function getAnalyticsTrends(days: number = 30): Promise<{
  trends: DailyTrendPoint[];
  insights: AnalyticsInsights;
}> {
  const startDate = startOfDay(subDays(new Date(), days - 1));

  // Fetch data
  const bookings = await prisma.booking.findMany({
    where: {
      status: BookingStatus.COMPLETED,
      updatedAt: { gte: startDate } // use updatedAt for revenue/completed bookings
    },
    select: {
      totalAmount: true,
      updatedAt: true,
      city: {
        select: { name: true }
      },
      services: {
        select: {
          service: {
            select: {
              category: { select: { name: true } }
            }
          },
          serviceSubcategory: {
            select: {
              category: { select: { name: true } }
            }
          }
        }
      }
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

  const cityMap = new Map<string, AnalyticsBreakdownItem>();
  const categoryMap = new Map<string, AnalyticsBreakdownItem>();

  for (const booking of bookings) {
    const revenue = Number(booking.totalAmount || 0);
    const cityLabel = booking.city?.name?.trim() || "Unknown city";
    const city = cityMap.get(cityLabel) ?? { label: cityLabel, bookings: 0, revenue: 0 };
    city.bookings += 1;
    city.revenue += revenue;
    cityMap.set(cityLabel, city);

    const categoryLabel =
      booking.services[0]?.service?.category?.name?.trim() ||
      booking.services[0]?.serviceSubcategory?.category?.name?.trim() ||
      "Uncategorized";
    const category = categoryMap.get(categoryLabel) ?? { label: categoryLabel, bookings: 0, revenue: 0 };
    category.bookings += 1;
    category.revenue += revenue;
    categoryMap.set(categoryLabel, category);
  }

  const sorter = (a: AnalyticsBreakdownItem, b: AnalyticsBreakdownItem) =>
    b.revenue - a.revenue || b.bookings - a.bookings || a.label.localeCompare(b.label);

  return {
    trends: Array.from(trendsMap.values()),
    insights: {
      byCity: Array.from(cityMap.values()).sort(sorter).slice(0, 6),
      byCategory: Array.from(categoryMap.values()).sort(sorter).slice(0, 6)
    }
  };
}
