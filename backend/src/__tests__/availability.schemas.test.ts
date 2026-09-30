import { describe, expect, it } from "vitest";
import { setWeeklyAvailabilitySchema } from "../modules/availability/availability.schemas.js";

const requestFor = (slots: Array<{
  dayOfWeek: number;
  startTime: string;
  endTime: string;
}>) => ({ body: { slots }, query: {}, params: {} });

describe("setWeeklyAvailabilitySchema", () => {
  it("accepts non-overlapping and adjacent slots on the same day", () => {
    const result = setWeeklyAvailabilitySchema.safeParse(requestFor([
      { dayOfWeek: 1, startTime: "09:00", endTime: "12:00" },
      { dayOfWeek: 1, startTime: "12:00", endTime: "17:00" },
      { dayOfWeek: 2, startTime: "09:00", endTime: "17:00" }
    ]));

    expect(result.success).toBe(true);
  });

  it("rejects overlapping slots on the same day", () => {
    const result = setWeeklyAvailabilitySchema.safeParse(requestFor([
      { dayOfWeek: 1, startTime: "09:00", endTime: "13:00" },
      { dayOfWeek: 1, startTime: "12:30", endTime: "17:00" }
    ]));

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues).toContainEqual(expect.objectContaining({
        message: "Availability time slots on the same day cannot overlap"
      }));
    }
  });
});
