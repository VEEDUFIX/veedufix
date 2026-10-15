import { randomUUID } from "node:crypto";
import { Prisma, UserRole } from "@prisma/client";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { destroyAuthenticatedImage, generateSignedUrl, uploadBufferToCloudinary } from "../../lib/cloudinary.js";

const MAX_BOOKING_PHOTOS = 5;
const STAGED_TTL_MS = 24 * 60 * 60 * 1000;
const UPLOAD_RESERVATION_TTL_MS = 15 * 60 * 1000;
const UPLOAD_RESERVATION_PREFIX = "reservation:";

type DiagnosticUploadFile = Pick<Express.Multer.File, "buffer" | "size" | "mimetype">;

function serializePhoto(photo: { id: string; publicId: string; format: string; bytes: number; createdAt: Date }) {
  return {
    id: photo.id,
    url: generateSignedUrl(photo.publicId, photo.format, 300),
    format: photo.format,
    bytes: photo.bytes,
    createdAt: photo.createdAt.toISOString()
  };
}

export async function uploadBookingDiagnosticPhoto(input: {
  userId: string;
  clientUploadId: string;
  file: DiagnosticUploadFile;
}) {
  const clientUploadId = input.clientUploadId.trim();
  if (!clientUploadId || clientUploadId.length > 120) {
    throw AppError.badRequest("A valid clientUploadId is required");
  }
  if (input.file.size <= 0 || input.file.size > 10 * 1024 * 1024) {
    throw AppError.badRequest("Image must be smaller than 10 MB");
  }
  if (input.file.mimetype !== "image/jpeg" && input.file.mimetype !== "image/png") {
    throw AppError.badRequest("Only JPEG and PNG images are supported");
  }

  const existing = await prisma.bookingDiagnosticPhoto.findUnique({
    where: { uploadedById_clientUploadId: { uploadedById: input.userId, clientUploadId } }
  });
  if (existing) {
    if (existing.bookingId !== null) {
      throw AppError.conflict("This image is already attached to a booking");
    }
    if (!existing.expiresAt || existing.expiresAt <= new Date()) {
      throw AppError.gone("This upload expired. Please select the image again.");
    }
    if (existing.publicId.startsWith(UPLOAD_RESERVATION_PREFIX)) {
      throw AppError.conflict("This photo upload is still processing. Retry in a moment.");
    }
    return serializePhoto(existing);
  }

  const extension = input.file.mimetype === "image/png" ? "png" : "jpg";
  const folder = `veedufix/booking-diagnostics/${input.userId}`;
  const publicId = `diagnostic-${randomUUID()}`;
  const reservationPublicId = `${UPLOAD_RESERVATION_PREFIX}${folder}/${publicId}`;
  let uploadedPublicId: string | null = null;
  let photo: Awaited<ReturnType<typeof prisma.bookingDiagnosticPhoto.update>>;
  try {
    const reservation = await prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${input.userId}))`;

      const canonical = await tx.bookingDiagnosticPhoto.findUnique({
        where: { uploadedById_clientUploadId: { uploadedById: input.userId, clientUploadId } }
      });
      if (canonical) {
        if (canonical.bookingId !== null) throw AppError.conflict("This image is already attached to a booking");
        if (!canonical.expiresAt || canonical.expiresAt <= new Date()) {
          throw AppError.gone("This upload expired. Please select the image again.");
        }
        if (canonical.publicId.startsWith(UPLOAD_RESERVATION_PREFIX)) {
          throw AppError.conflict("This photo upload is still processing. Retry in a moment.");
        }
        return { photo: canonical, isReservation: false };
      }

      const stagedCount = await tx.bookingDiagnosticPhoto.count({
        where: { uploadedById: input.userId, bookingId: null, expiresAt: { gt: new Date() } }
      });
      if (stagedCount >= MAX_BOOKING_PHOTOS) {
        throw AppError.badRequest("You can attach up to 5 photos to a booking");
      }

      const reservedPhoto = await tx.bookingDiagnosticPhoto.create({
        data: {
          uploadedById: input.userId,
          clientUploadId,
          publicId: reservationPublicId,
          format: extension,
          bytes: input.file.size,
          expiresAt: new Date(Date.now() + UPLOAD_RESERVATION_TTL_MS)
        }
      });
      return { photo: reservedPhoto, isReservation: true };
    });
    if (!reservation.isReservation) return serializePhoto(reservation.photo);

    const uploaded = await uploadBufferToCloudinary(input.file.buffer, {
      folder,
      public_id: publicId,
      resource_type: "image",
      type: "authenticated",
      overwrite: false,
      format: extension
    });
    uploadedPublicId = uploaded.public_id;
    photo = await prisma.bookingDiagnosticPhoto.update({
      where: { id: reservation.photo.id, publicId: reservationPublicId },
      data: {
        publicId: uploaded.public_id,
        format: uploaded.format || extension,
        bytes: uploaded.bytes ?? input.file.size,
        expiresAt: new Date(Date.now() + STAGED_TTL_MS)
      }
    });
  } catch (error) {
    let storageCleaned = !uploadedPublicId;
    if (uploadedPublicId) {
      try {
        await destroyAuthenticatedImage(uploadedPublicId);
        storageCleaned = true;
      } catch {
        // Keep a durable reservation so the expiry job can retry storage cleanup.
        try {
          await prisma.bookingDiagnosticPhoto.updateMany({
            where: { uploadedById: input.userId, clientUploadId, publicId: reservationPublicId, bookingId: null },
            data: { publicId: uploadedPublicId, expiresAt: new Date(Date.now() + STAGED_TTL_MS) }
          });
        } catch {
          // The reservation embeds the requested public ID for cleanup fallback.
        }
      }
    }
    if (storageCleaned) {
      try {
        await prisma.bookingDiagnosticPhoto.deleteMany({
          where: { uploadedById: input.userId, clientUploadId, publicId: reservationPublicId, bookingId: null }
        });
      } catch {
        // Expiry cleanup can remove the stale reservation after storage is clean.
      }
    }
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === "P2002") {
      const canonical = await prisma.bookingDiagnosticPhoto.findUnique({
        where: { uploadedById_clientUploadId: { uploadedById: input.userId, clientUploadId } }
      });
      if (
        canonical?.bookingId === null && canonical.expiresAt && canonical.expiresAt > new Date() &&
        !canonical.publicId.startsWith(UPLOAD_RESERVATION_PREFIX)
      ) {
        return serializePhoto(canonical);
      }
      throw AppError.conflict("This photo upload is already being processed");
    }
    throw error;
  }
  return serializePhoto(photo!);
}

export async function deleteStagedBookingDiagnosticPhoto(userId: string, photoId: string): Promise<void> {
  const photo = await prisma.bookingDiagnosticPhoto.findFirst({ where: { id: photoId, uploadedById: userId } });
  if (!photo) throw AppError.notFound("Photo upload not found");
  if (photo.bookingId !== null) throw AppError.conflict("A photo attached to a booking cannot be removed here");
  if (photo.publicId.startsWith(UPLOAD_RESERVATION_PREFIX)) {
    throw AppError.conflict("This photo upload is still processing. Retry in a moment.");
  }
  const claimedExpiresAt = new Date(
    Math.min(Date.now() - 1, (photo.expiresAt?.getTime() ?? Date.now()) - 1)
  );
  const claimed = await prisma.bookingDiagnosticPhoto.updateMany({
    where: {
      id: photo.id,
      uploadedById: userId,
      bookingId: null,
      expiresAt: photo.expiresAt
    },
    data: { expiresAt: claimedExpiresAt }
  });
  if (claimed.count !== 1) {
    throw AppError.conflict("A photo attached to a booking cannot be removed here");
  }
  await destroyAuthenticatedImage(photo.publicId);
  // Keep the row until storage deletion succeeds so the scheduled cleanup can
  // retry if Cloudinary is temporarily unavailable.
  await prisma.bookingDiagnosticPhoto.deleteMany({
    where: {
      id: photo.id,
      uploadedById: userId,
      bookingId: null,
      expiresAt: claimedExpiresAt
    }
  });
}

export async function getBookingDiagnosticPhotos(input: {
  bookingId: string;
  userId: string;
  role: UserRole;
}) {
  const booking = await prisma.booking.findUnique({
    where: { id: input.bookingId },
    select: { id: true, customerId: true, worker: { select: { userId: true } } }
  });
  if (!booking) throw AppError.notFound("Booking not found");

  const authorized = input.role === "ADMIN" ||
    (input.role === "CUSTOMER" && booking.customerId === input.userId) ||
    (input.role === "WORKER" && booking.worker?.userId === input.userId);
  if (!authorized) throw AppError.forbidden("You are not allowed to view these booking photos");

  const photos = await prisma.bookingDiagnosticPhoto.findMany({
    where: { bookingId: booking.id },
    orderBy: { createdAt: "asc" }
  });
  return photos.map((photo) => serializePhoto(photo as { id: string; publicId: string; format: string; bytes: number; createdAt: Date }));
}

export async function cleanupExpiredBookingDiagnosticPhotos(now = new Date()): Promise<number> {
  const cleanupCutoff = new Date(now.getTime() - STAGED_TTL_MS);
  const expired = await prisma.bookingDiagnosticPhoto.findMany({
    where: {
      bookingId: null,
      OR: [
        { expiresAt: { lte: now } },
        { expiresAt: null, createdAt: { lte: cleanupCutoff } }
      ]
    },
    select: { id: true, publicId: true, expiresAt: true, createdAt: true }
  });
  let removed = 0;
  for (const photo of expired) {
    const claimExpiresAt = new Date(Math.min(
      now.getTime() - 1,
      (photo.expiresAt?.getTime() ?? now.getTime()) - 1
    ));
    const claimWhere = {
      id: photo.id,
      bookingId: null,
      AND: photo.expiresAt
        ? [
            { expiresAt: { lte: now } },
            { expiresAt: photo.expiresAt }
          ]
        : [
            { expiresAt: null },
            { createdAt: { lte: cleanupCutoff } }
          ]
    };
    let claimed = false;
    try {
      const claim = await prisma.bookingDiagnosticPhoto.updateMany({
        where: claimWhere,
        data: { expiresAt: claimExpiresAt }
      });
      if (claim.count !== 1) continue;
      claimed = true;

      if (photo.publicId.startsWith(UPLOAD_RESERVATION_PREFIX)) {
        const reservedPublicId = photo.publicId.slice(UPLOAD_RESERVATION_PREFIX.length);
        await destroyAuthenticatedImage(reservedPublicId);
        // Cloudinary fixed-folder accounts qualify public IDs with the folder,
        // while dynamic-folder accounts may keep only the supplied public_id.
        const unqualifiedPublicId = reservedPublicId.slice(reservedPublicId.lastIndexOf("/") + 1);
        if (unqualifiedPublicId !== reservedPublicId) {
          await destroyAuthenticatedImage(unqualifiedPublicId);
        }
        const deleted = await prisma.bookingDiagnosticPhoto.deleteMany({
          where: { id: photo.id, bookingId: null, publicId: photo.publicId, expiresAt: claimExpiresAt }
        });
        removed += deleted.count;
        continue;
      }
      await destroyAuthenticatedImage(photo.publicId);
      const deleted = await prisma.bookingDiagnosticPhoto.deleteMany({
        where: { id: photo.id, bookingId: null, expiresAt: claimExpiresAt }
      });
      removed += deleted.count;
    } catch {
      if (claimed) {
        try {
          await prisma.bookingDiagnosticPhoto.updateMany({
            where: { id: photo.id, bookingId: null, expiresAt: claimExpiresAt },
            data: { expiresAt: photo.expiresAt }
          });
        } catch {
          // The claim lease expires, allowing a later scheduled run to retry.
        }
      }
    }
  }
  return removed;
}
