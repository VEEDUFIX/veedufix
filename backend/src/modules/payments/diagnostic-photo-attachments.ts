import { Prisma } from "@prisma/client";
import { AppError } from "../../lib/app-error.js";

export async function attachDiagnosticPhotosToBooking(
  tx: Prisma.TransactionClient,
  input: { userId: string; bookingId: string; photoIds?: string[] }
): Promise<void> {
  const photoIds = input.photoIds ?? [];
  if (photoIds.length === 0) return;
  if (photoIds.length > 5 || new Set(photoIds).size !== photoIds.length) {
    throw AppError.badRequest("Choose up to 5 unique diagnostic photos");
  }
  const attached = await tx.bookingDiagnosticPhoto.updateMany({
    where: {
      id: { in: photoIds },
      uploadedById: input.userId,
      bookingId: null,
      publicId: { not: { startsWith: "reservation:" } },
      expiresAt: { gt: new Date() }
    },
    data: { bookingId: input.bookingId, expiresAt: null }
  });
  if (attached.count !== photoIds.length) {
    throw AppError.conflict("One or more diagnostic photos expired or are no longer available. Retry the booking.");
  }
}
