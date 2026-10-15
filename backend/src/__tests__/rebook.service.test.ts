import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/prisma.js", () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
    savedAddress: { findMany: vi.fn() }
  }
}));

import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/app-error.js";
import { getRebookOptions } from "../modules/bookings/rebook.service.js";

const source = (overrides: Record<string, unknown> = {}) => ({
  id: "booking-1",
  code: "BK-1",
  customerId: "customer-1",
  status: "COMPLETED",
  customQuoteStatus: "ACCEPTED",
  customQuoteRevisions: [{ id: "quote-1" }],
  disputes: [],
  address: {
    label: "Home",
    line1: "12 Main Road",
    pincode: "600001",
    city: { name: "Chennai" }
  },
  services: [{
    serviceId: "service-1",
    quantity: 2,
    configuration: {
      baseUnitPrice: "9999",
      variant: { id: "variant-1", unitPrice: "9999" },
      addons: [{ id: "addon-1", unitPrice: "500" }]
    },
    service: { id: "service-1", name: "AC Service", slug: "ac-service", isActive: true, bookingEnabled: true, publicationStatus: "PUBLISHED" },
    serviceSubcategory: { name: "Air Conditioning" }
  }],
  ...overrides
});

describe("getRebookOptions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.savedAddress.findMany).mockResolvedValue([{
      id: "saved-address-1",
      label: "Home",
      addressLine1: "12 Main Road",
      addressLine2: null,
      landmark: null,
      city: "Chennai",
      pincode: "600001"
    }] as never);
  });

  it("returns only reusable selections and matches the customer's saved address", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(source() as never);

    const result = await getRebookOptions("booking-1", "customer-1");

    expect(result.canRebook).toBe(true);
    expect(result.preferredAddressId).toBe("saved-address-1");
    expect(result.previouslyQuoted).toBe(true);
    expect(result.items).toEqual([{
      serviceId: "service-1",
      serviceName: "AC Service",
      serviceSlug: "ac-service",
      quantity: 2,
      variantId: "variant-1",
      addonIds: ["addon-1"],
      serviceCurrentlyBookable: true
    }]);
    expect(JSON.stringify(result)).not.toContain("9999");
    expect(JSON.stringify(result)).not.toContain("quote-1");
  });

  it("blocks non-completed bookings and active claims", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(source({ status: "CANCELLED" }) as never);
    expect((await getRebookOptions("booking-1", "customer-1")).canRebook).toBe(false);

    vi.mocked(prisma.booking.findUnique).mockResolvedValue(source({
      disputes: [{ status: "under_review" }]
    }) as never);
    expect((await getRebookOptions("booking-1", "customer-1")).reason).toContain("active claim");
  });

  it("does not offer rebooking when every original service is currently unavailable", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(source({
      services: [{
        serviceId: "service-1",
        quantity: 1,
        configuration: {},
        service: { id: "service-1", name: "AC Service", slug: "ac-service", isActive: false, bookingEnabled: false, publicationStatus: "ARCHIVED" },
        serviceSubcategory: { name: "Air Conditioning" }
      }]
    }) as never);
    const result = await getRebookOptions("booking-1", "customer-1");
    expect(result.canRebook).toBe(false);
    expect(result.reason).toContain("not currently available");
  });

  it("does not reveal another customer's booking", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue(source() as never);
    await expect(getRebookOptions("booking-1", "other-customer")).rejects.toMatchObject<AppError>({
      statusCode: 403
    });
    expect(prisma.savedAddress.findMany).not.toHaveBeenCalled();
  });
});
