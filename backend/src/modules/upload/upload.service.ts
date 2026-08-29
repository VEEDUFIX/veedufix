import { v2 as cloudinary } from "cloudinary";
import { prisma } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";
import { env } from "../../config/env.js";
import { uploadBufferToCloudinary } from "../../lib/cloudinary.js";
import { publishNotificationEvent, publishTrackingEvent } from "../../lib/realtime.js";

export type JobPhotoType = "before" | "after";

export type UploadSignatureResponse = {
  cloudName: string;
  apiKey: string;
  folder: string;
  timestamp: number;
  signature: string;
  uploadUrl: string;
};

export type UploadedJobPhoto = {
  secureUrl: string;
  publicId: string;
  folder: string;
  bytes: number;
  format?: string;
};

export type UploadedChatAttachment = {
  secureUrl: string;
  publicId: string;
  folder: string;
  bytes: number;
  format?: string;
};

let configured = false;

function ensureConfigured(): void {
  if (configured) {
    return;
  }

  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new AppError(500, "Cloudinary credentials are not configured");
  }

  cloudinary.config({
    cloud_name: env.CLOUDINARY_CLOUD_NAME,
    api_key: env.CLOUDINARY_API_KEY,
    api_secret: env.CLOUDINARY_API_SECRET,
    secure: true
  });

  configured = true;
}

function jobPhotoFolder(bookingId: string, type: JobPhotoType): string {
  return `veedufix/jobs/${bookingId}/${type}`;
}

function jobPhotoPublicId(bookingId: string, type: JobPhotoType): string {
  const suffix = Math.random().toString(36).slice(2, 10);
  return `job-photo-${bookingId}-${type}-${Date.now()}-${suffix}`;
}

async function getBookingForWorkerUpload(bookingId: string, userId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: {
        include: {
          user: true
        }
      }
    }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  if (!booking.worker || booking.worker.userId !== userId) {
    throw AppError.forbidden("You are not assigned to this booking");
  }

  return booking;
}

export async function assertWorkerCanUploadJobPhoto(bookingId: string, userId: string): Promise<void> {
  await getBookingForWorkerUpload(bookingId, userId);
}

function jobPhotoStatus(type: JobPhotoType): string {
  return type === "before" ? "JOB_PHOTO_BEFORE_UPLOADED" : "JOB_PHOTO_AFTER_UPLOADED";
}

async function getBookingForChatUpload(bookingId: string, userId: string) {
  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: {
        select: {
          userId: true
        }
      }
    }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  const isCustomer = booking.customerId === userId;
  const isWorker = booking.worker?.userId === userId;
  if (!isCustomer && !isWorker) {
    throw AppError.forbidden("You are not part of this booking");
  }

  return booking;
}

function jobPhotoTitle(type: JobPhotoType): string {
  return type === "before" ? "Before photo uploaded" : "After photo uploaded";
}

function jobPhotoBody(type: JobPhotoType, bookingCode: string): string {
  return `${type === "before" ? "Before" : "After"} photo uploaded for booking ${bookingCode}.`;
}

async function recordJobPhotoUpload(
  bookingId: string,
  userId: string,
  type: JobPhotoType,
  photo: UploadedJobPhoto
) {
  const booking = await getBookingForWorkerUpload(bookingId, userId);
  const title = jobPhotoTitle(type);
  const body = jobPhotoBody(type, booking.code);
  const data = {
    bookingId: booking.id,
    bookingCode: booking.code,
    photoType: type,
    photoUrl: photo.secureUrl,
    photoPublicId: photo.publicId,
    photoFolder: photo.folder,
    photoBytes: photo.bytes,
    photoFormat: photo.format ?? null
  };

  const timelineEvent = await prisma.bookingTimelineEvent.create({
    data: {
      bookingId: booking.id,
      status: booking.status,
      title,
      description: body
    }
  });

  await prisma.notification.create({
    data: {
      userId: booking.customerId,
      title,
      body,
      type: "JOB_EXECUTION",
      data
    }
  });

  await publishNotificationEvent({
    userId: booking.customerId,
    title,
    body,
    type: "JOB_EXECUTION",
    data
  });

  await publishTrackingEvent({
    bookingId: booking.id,
    bookingCode: booking.code,
    status: jobPhotoStatus(type),
    message: body,
    actorRole: "WORKER",
    photoType: type,
    photoUrl: photo.secureUrl,
    photoPublicId: photo.publicId,
    photoFolder: photo.folder
  });

  return {
    bookingId: booking.id,
    bookingCode: booking.code,
    timelineEvent,
    notification: data
  };
}

export async function uploadJobPhoto(
  fileBuffer: Buffer,
  bookingId: string,
  type: JobPhotoType
): Promise<UploadedJobPhoto> {
  ensureConfigured();

  const folder = jobPhotoFolder(bookingId, type);
  const uploaded = await uploadBufferToCloudinary(fileBuffer, {
    folder,
    public_id: jobPhotoPublicId(bookingId, type),
    resource_type: "image",
    overwrite: true
  });

  return {
    secureUrl: uploaded.secure_url,
    publicId: uploaded.public_id,
    folder,
    bytes: uploaded.bytes ?? fileBuffer.length,
    format: uploaded.format
  };
}

export async function uploadChatAttachment(
  fileBuffer: Buffer,
  bookingId: string,
  userId: string,
  filename?: string
): Promise<UploadedChatAttachment> {
  ensureConfigured();
  await getBookingForChatUpload(bookingId, userId);

  const folder = `veedufix/chat/${bookingId}/${userId}`;
  const suffix = Math.random().toString(36).slice(2, 10);
  const publicId = `chat-attachment-${Date.now()}-${suffix}${filename ? `-${filename.replace(/[^a-zA-Z0-9._-]/g, "_")}` : ""}`;
  const uploaded = await uploadBufferToCloudinary(fileBuffer, {
    folder,
    public_id: publicId,
    resource_type: "image",
    overwrite: true
  });

  return {
    secureUrl: uploaded.secure_url,
    publicId: uploaded.public_id,
    folder,
    bytes: uploaded.bytes ?? fileBuffer.length,
    format: uploaded.format
  };
}

export async function uploadAndRecordJobPhoto(
  fileBuffer: Buffer,
  bookingId: string,
  userId: string,
  type: JobPhotoType
) {
  const photo = await uploadJobPhoto(fileBuffer, bookingId, type);
  const recorded = await recordJobPhotoUpload(bookingId, userId, type, photo);

  return {
    ...photo,
    ...recorded
  };
}

export async function deleteJobPhoto(publicId: string): Promise<{ publicId: string; deleted: boolean }> {
  ensureConfigured();

  const result = await cloudinary.uploader.destroy(publicId, {
    resource_type: "image",
    invalidate: true
  });

  return {
    publicId,
    deleted: result.result === "ok" || result.result === "not found"
  };
}

export async function generateUploadSignature(
  bookingId: string,
  type: JobPhotoType
): Promise<UploadSignatureResponse> {
  ensureConfigured();

  const folder = jobPhotoFolder(bookingId, type);
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = cloudinary.utils.api_sign_request(
    {
      folder,
      timestamp
    },
    env.CLOUDINARY_API_SECRET!
  );

  return {
    cloudName: env.CLOUDINARY_CLOUD_NAME!,
    apiKey: env.CLOUDINARY_API_KEY!,
    folder,
    timestamp,
    signature,
    uploadUrl: `https://api.cloudinary.com/v1_1/${env.CLOUDINARY_CLOUD_NAME}/image/upload`
  };
}

export async function confirmJobPhotoUpload(
  bookingId: string,
  userId: string,
  type: JobPhotoType,
  photo: Omit<UploadedJobPhoto, "folder">
) {
  const recorded = await recordJobPhotoUpload(bookingId, userId, type, {
    ...photo,
    folder: jobPhotoFolder(bookingId, type)
  });

  return recorded;
}
