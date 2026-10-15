import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";

const activeClaimStatuses = new Set([
  "open",
  "under_review",
  "action_required",
  "approved",
  "refund_pending",
  "resolved_rework"
]);

function normalizeAddressPart(value: string | null | undefined): string {
  return (value ?? "").trim().toLocaleLowerCase().replace(/\s+/g, " ");
}

function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

export async function getRebookOptions(bookingId: string, customerId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      services: {
        include: {
          service: { select: { id: true, name: true, slug: true, isActive: true, bookingEnabled: true, publicationStatus: true } },
          serviceSubcategory: { select: { name: true } }
        }
      },
      address: { include: { city: { select: { name: true } } } },
      disputes: { select: { status: true } },
      customQuoteRevisions: { select: { id: true } }
    }
  });

  if (!booking) throw AppError.notFound("Booking not found");
  if (booking.customerId !== customerId) throw AppError.forbidden("Access denied");

  const activeClaim = booking.disputes.some((dispute: { status: string }) =>
    activeClaimStatuses.has(dispute.status)
  );
  const completed = booking.status === "COMPLETED";
  const savedAddresses = await prisma.savedAddress.findMany({
    where: { userId: customerId },
    select: { id: true, label: true, addressLine1: true, addressLine2: true, landmark: true, city: true, pincode: true }
  });
  const previousAddress = booking.address;
  const matchedAddress = previousAddress
    ? savedAddresses.find((address) =>
        normalizeAddressPart(address.pincode) === normalizeAddressPart(previousAddress.pincode) &&
        normalizeAddressPart(address.city) === normalizeAddressPart(previousAddress.city.name) &&
        normalizeAddressPart(address.addressLine1) === normalizeAddressPart(previousAddress.line1) &&
        normalizeAddressPart(address.addressLine2) === normalizeAddressPart(previousAddress.line2) &&
        normalizeAddressPart(address.landmark) === normalizeAddressPart(previousAddress.landmark) &&
        normalizeAddressPart(address.label) === normalizeAddressPart(previousAddress.label)
      )
    : undefined;

  const items = booking.services.map((item: {
    serviceId: string | null;
    quantity: number;
    configuration: unknown;
    service: {
      name: string;
      slug: string;
      isActive: boolean;
      bookingEnabled: boolean;
      publicationStatus: string;
    } | null;
    serviceSubcategory: { name: string };
  }) => {
    const configuration = asRecord(item.configuration);
    const variant = asRecord(configuration.variant);
    const rawAddons = Array.isArray(configuration.addons) ? configuration.addons : [];
    const addonIds = rawAddons.flatMap((value) => {
      const id = asRecord(value).id;
      return typeof id === "string" && id.length > 0 ? [id] : [];
    });
    return {
      serviceId: item.serviceId,
      serviceName: item.service?.name ?? item.serviceSubcategory.name,
      serviceSlug: item.service?.slug ?? null,
      quantity: item.quantity,
      variantId: typeof variant.id === "string" ? variant.id : null,
      addonIds,
      serviceCurrentlyBookable: Boolean(
        item.service?.isActive &&
        item.service.bookingEnabled &&
        item.service.publicationStatus === "PUBLISHED"
      )
    };
  });

  let reason: string | null = null;
  if (!completed) reason = "Only completed bookings can be booked again.";
  else if (activeClaim) reason = "This booking has an active claim. Resolve it before booking this service again.";
  else if (items.length === 0) reason = "The original service details are no longer available.";
  else if (!items.some((item: { serviceCurrentlyBookable: boolean }) => item.serviceCurrentlyBookable)) {
    reason = "The original services are not currently available to book again.";
  }

  return {
    sourceBookingId: booking.id,
    sourceBookingCode: booking.code,
    canRebook: reason === null,
    reason,
    previouslyQuoted: booking.customQuoteRevisions.length > 0 || booking.customQuoteStatus != null,
    preferredAddressId: matchedAddress?.id ?? null,
    addressMatched: matchedAddress !== undefined,
    items
  };
}
