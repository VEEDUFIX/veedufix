import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/prisma.js", () => ({
  prisma: {
    bookingDiagnosticPhoto: {
      findUnique: vi.fn(),
      count: vi.fn(),
      create: vi.fn(),
      update: vi.fn(),
      findFirst: vi.fn(),
      updateMany: vi.fn(),
      deleteMany: vi.fn(),
      findMany: vi.fn()
    },
    booking: { findUnique: vi.fn() },
    $executeRaw: vi.fn(),
    $transaction: vi.fn()
  }
}));
vi.mock("../lib/cloudinary.js", () => ({
  uploadBufferToCloudinary: vi.fn(),
  generateSignedUrl: vi.fn(() => "https://private.example/signed"),
  destroyAuthenticatedImage: vi.fn()
}));

import { prisma } from "../lib/prisma.js";
import { destroyAuthenticatedImage, generateSignedUrl, uploadBufferToCloudinary } from "../lib/cloudinary.js";
import { cleanupExpiredBookingDiagnosticPhotos, deleteStagedBookingDiagnosticPhoto, getBookingDiagnosticPhotos, uploadBookingDiagnosticPhoto } from "../modules/media/booking-diagnostic-photo.service.js";
import { createPaymentOrderSchema } from "../modules/payments/payments.schemas.js";
import { attachDiagnosticPhotosToBooking } from "../modules/payments/diagnostic-photo-attachments.js";
import { validateImageContent } from "../middleware/validate-image-content.js";

const validFile = { buffer: Buffer.from([0xff, 0xd8, 0xff, 0]), size: 4, mimetype: "image/jpeg" };
const stagedPhoto = { id: "photo-1", publicId: "private/photo-1", format: "jpg", bytes: 4, createdAt: new Date(), bookingId: null, expiresAt: new Date(Date.now() + 60_000) };

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(prisma.$transaction).mockImplementation((callback) => callback(prisma) as never);
  vi.mocked(prisma.$executeRaw).mockResolvedValue(1);
  vi.mocked(prisma.bookingDiagnosticPhoto.findUnique).mockResolvedValue(null as never);
  vi.mocked(prisma.bookingDiagnosticPhoto.count).mockResolvedValue(0 as never);
  vi.mocked(prisma.bookingDiagnosticPhoto.create).mockResolvedValue(stagedPhoto as never);
  vi.mocked(prisma.bookingDiagnosticPhoto.update).mockResolvedValue(stagedPhoto as never);
  vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 1 } as never);
  vi.mocked(uploadBufferToCloudinary).mockResolvedValue({ public_id: "private/photo-1", format: "jpg", bytes: 4 } as never);
});

describe("booking diagnostic photos", () => {
  it("accepts JPEG and stages it as a private upload", async () => {
    const result = await uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile });
    expect(uploadBufferToCloudinary).toHaveBeenCalledWith(validFile.buffer, expect.objectContaining({
      folder: "veedufix/booking-diagnostics/customer-1",
      type: "authenticated",
      overwrite: false
    }));
    expect(prisma.$executeRaw).toHaveBeenCalledOnce();
    expect(prisma.bookingDiagnosticPhoto.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ uploadedById: "customer-1", clientUploadId: "upload-1", expiresAt: expect.any(Date) }) }));
    expect(result.url).toBe("https://private.example/signed");
  });

  it("performs the Cloudinary transfer only after the reservation transaction commits", async () => {
    let transactionCommitted = false;
    vi.mocked(prisma.$transaction).mockImplementation(async (callback) => {
      const result = await callback(prisma as never);
      transactionCommitted = true;
      return result as never;
    });
    vi.mocked(uploadBufferToCloudinary).mockImplementation(async () => {
      expect(transactionCommitted).toBe(true);
      return { public_id: "private/photo-1", format: "jpg", bytes: 4 } as never;
    });

    await uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile });

    expect(prisma.bookingDiagnosticPhoto.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        publicId: expect.stringMatching(/^reservation:veedufix\/booking-diagnostics\/customer-1\/diagnostic-/)
      })
    }));
    expect(prisma.bookingDiagnosticPhoto.update).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ publicId: expect.stringMatching(/^reservation:/) }),
      data: expect.objectContaining({ publicId: "private/photo-1", expiresAt: expect.any(Date) })
    }));
  });

  it("rejects unsupported type, empty file, and over-limit file before storage", async () => {
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "x", file: { ...validFile, mimetype: "image/gif" } })).rejects.toMatchObject({ statusCode: 400 });
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "x", file: { ...validFile, size: 0 } })).rejects.toMatchObject({ statusCode: 400 });
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "x", file: { ...validFile, size: 10 * 1024 * 1024 + 1 } })).rejects.toMatchObject({ statusCode: 400 });
    expect(uploadBufferToCloudinary).not.toHaveBeenCalled();
  });

  it("returns the existing upload on a retried clientUploadId", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findUnique).mockResolvedValue(stagedPhoto as never);
    const result = await uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile });
    expect(result.id).toBe("photo-1");
    expect(uploadBufferToCloudinary).not.toHaveBeenCalled();
  });

  it("does not expose or return an in-progress reservation as a photo", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findUnique).mockResolvedValue({
      ...stagedPhoto, publicId: "reservation:diagnostic-pending"
    } as never);

    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile }))
      .rejects.toMatchObject({ statusCode: 409 });
    expect(uploadBufferToCloudinary).not.toHaveBeenCalled();
    expect(generateSignedUrl).not.toHaveBeenCalled();
  });

  it("enforces the staging count limit", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.count).mockResolvedValue(5 as never);
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-6", file: validFile })).rejects.toMatchObject({ statusCode: 400 });
    expect(uploadBufferToCloudinary).not.toHaveBeenCalled();
  });

  it("allows only the booking customer, current assigned Partner, or Admin to read signed photos", async () => {
    vi.mocked(prisma.booking.findUnique).mockResolvedValue({ id: "booking-1", customerId: "customer-1", worker: { userId: "worker-1" } } as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.findMany).mockResolvedValue([stagedPhoto] as never);
    await expect(getBookingDiagnosticPhotos({ bookingId: "booking-1", userId: "other", role: "CUSTOMER" })).rejects.toMatchObject({ statusCode: 403 });
    await expect(getBookingDiagnosticPhotos({ bookingId: "booking-1", userId: "worker-2", role: "WORKER" })).rejects.toMatchObject({ statusCode: 403 });
    await expect(getBookingDiagnosticPhotos({ bookingId: "booking-1", userId: "customer-1", role: "CUSTOMER" })).resolves.toHaveLength(1);
    await expect(getBookingDiagnosticPhotos({ bookingId: "booking-1", userId: "worker-1", role: "WORKER" })).resolves.toHaveLength(1);
    await expect(getBookingDiagnosticPhotos({ bookingId: "booking-1", userId: "admin-1", role: "ADMIN" })).resolves.toHaveLength(1);
    expect(generateSignedUrl).toHaveBeenCalled();
  });

  it("does not let a Customer delete a photo after it is linked to a booking", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findFirst).mockResolvedValue({ ...stagedPhoto, bookingId: "booking-1" } as never);
    await expect(deleteStagedBookingDiagnosticPhoto("customer-1", "photo-1")).rejects.toMatchObject({ statusCode: 409 });
    expect(destroyAuthenticatedImage).not.toHaveBeenCalled();
  });

  it("claims a staged row before destroying its Cloudinary asset", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findFirst).mockResolvedValue(stagedPhoto as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 1 } as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.deleteMany).mockResolvedValue({ count: 1 } as never);

    await deleteStagedBookingDiagnosticPhoto("customer-1", "photo-1");

    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledWith({
      where: {
        id: "photo-1",
        uploadedById: "customer-1",
        bookingId: null,
        expiresAt: stagedPhoto.expiresAt
      },
      data: { expiresAt: expect.any(Date) }
    });
    expect(vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mock.invocationCallOrder[0])
      .toBeLessThan(vi.mocked(destroyAuthenticatedImage).mock.invocationCallOrder[0]);
    expect(vi.mocked(destroyAuthenticatedImage).mock.invocationCallOrder[0])
      .toBeLessThan(vi.mocked(prisma.bookingDiagnosticPhoto.deleteMany).mock.invocationCallOrder[0]);
    expect(destroyAuthenticatedImage).toHaveBeenCalledWith("private/photo-1");
  });

  it("preserves the Cloudinary asset if the staged row was attached before deletion", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findFirst).mockResolvedValue(stagedPhoto as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 0 } as never);

    await expect(deleteStagedBookingDiagnosticPhoto("customer-1", "photo-1"))
      .rejects.toMatchObject({ statusCode: 409 });

    expect(destroyAuthenticatedImage).not.toHaveBeenCalled();
  });

  it("keeps the staged database row when Cloudinary deletion fails so cleanup can retry", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findFirst).mockResolvedValue(stagedPhoto as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 1 } as never);
    vi.mocked(destroyAuthenticatedImage).mockRejectedValueOnce(new Error("storage unavailable"));

    await expect(deleteStagedBookingDiagnosticPhoto("customer-1", "photo-1"))
      .rejects.toThrow("storage unavailable");

    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledOnce();
    expect(prisma.bookingDiagnosticPhoto.deleteMany).not.toHaveBeenCalled();
  });


  it("rejects image content whose bytes do not match its JPEG/PNG MIME type", () => {
    const response = { status: vi.fn().mockReturnThis(), json: vi.fn() };
    const next = vi.fn();
    validateImageContent({ file: { mimetype: "image/png", buffer: Buffer.from("GIF89a") } } as never, response as never, next);
    expect(response.status).toHaveBeenCalledWith(400);
    expect(next).not.toHaveBeenCalled();
  });

  it("removes expired staged Cloudinary images and their rows", async () => {
    const now = new Date("2026-10-10T00:00:00Z");
    const expiredAt = new Date("2026-10-09T00:00:00Z");
    vi.mocked(prisma.bookingDiagnosticPhoto.findMany).mockResolvedValue([{
      id: "photo-expired", publicId: "private/expired", expiresAt: expiredAt, createdAt: expiredAt
    }] as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.deleteMany).mockResolvedValue({ count: 1 } as never);
    const removed = await cleanupExpiredBookingDiagnosticPhotos(now);
    expect(removed).toBe(1);
    expect(destroyAuthenticatedImage).toHaveBeenCalledWith("private/expired");
    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledWith({
      where: {
        id: "photo-expired",
        bookingId: null,
        AND: [
          { expiresAt: { lte: now } },
          { expiresAt: expiredAt }
        ]
      },
      data: { expiresAt: expect.any(Date) }
    });
    const claimExpiresAt = vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mock.calls[0][0].data.expiresAt;
    expect(prisma.bookingDiagnosticPhoto.deleteMany).toHaveBeenCalledWith({
      where: { id: "photo-expired", bookingId: null, expiresAt: claimExpiresAt }
    });
    expect(vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mock.invocationCallOrder[0])
      .toBeLessThan(vi.mocked(destroyAuthenticatedImage).mock.invocationCallOrder[0]);
  });

  it("releases the cleanup claim when storage removal fails", async () => {
    const now = new Date("2026-10-10T00:00:00Z");
    const expiredAt = new Date("2026-10-09T00:00:00Z");
    vi.mocked(prisma.bookingDiagnosticPhoto.findMany).mockResolvedValue([{
      id: "photo-expired", publicId: "private/expired", expiresAt: expiredAt, createdAt: expiredAt
    }] as never);
    vi.mocked(destroyAuthenticatedImage).mockRejectedValueOnce(new Error("storage unavailable"));

    const removed = await cleanupExpiredBookingDiagnosticPhotos(now);

    expect(removed).toBe(0);
    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenNthCalledWith(2, {
      where: {
        id: "photo-expired",
        bookingId: null,
        expiresAt: new Date(expiredAt.getTime() - 1)
      },
      data: { expiresAt: expiredAt }
    });
    expect(prisma.bookingDiagnosticPhoto.deleteMany).not.toHaveBeenCalled();
  });

  it("skips expired photo cleanup when another process already claimed the row", async () => {
    const now = new Date("2026-10-10T00:00:00Z");
    vi.mocked(prisma.bookingDiagnosticPhoto.findMany).mockResolvedValue([{
      id: "photo-expired", publicId: "private/expired", expiresAt: new Date("2026-10-09T00:00:00Z"), createdAt: new Date("2026-10-08T00:00:00Z")
    }] as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mockResolvedValue({ count: 0 } as never);

    const removed = await cleanupExpiredBookingDiagnosticPhotos(now);

    expect(removed).toBe(0);
    expect(destroyAuthenticatedImage).not.toHaveBeenCalled();
    expect(prisma.bookingDiagnosticPhoto.deleteMany).not.toHaveBeenCalled();
  });

  it("cleans expired reservations using their deterministic uploaded asset ID", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.findMany).mockResolvedValue([
      { id: "reservation-1", publicId: "reservation:veedufix/booking-diagnostics/customer-1/diagnostic-pending", expiresAt: new Date("2026-10-09T00:00:00Z"), createdAt: new Date("2026-10-08T00:00:00Z") }
    ] as never);
    vi.mocked(prisma.bookingDiagnosticPhoto.deleteMany).mockResolvedValue({ count: 1 } as never);

    const removed = await cleanupExpiredBookingDiagnosticPhotos(new Date("2026-10-10T00:00:00Z"));

    expect(removed).toBe(1);
    expect(destroyAuthenticatedImage).toHaveBeenCalledWith("veedufix/booking-diagnostics/customer-1/diagnostic-pending");
    expect(destroyAuthenticatedImage).toHaveBeenCalledWith("diagnostic-pending");
    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledOnce();
    const claimExpiresAt = vi.mocked(prisma.bookingDiagnosticPhoto.updateMany).mock.calls[0][0].data.expiresAt;
    expect(prisma.bookingDiagnosticPhoto.deleteMany).toHaveBeenCalledWith({
      where: { id: "reservation-1", bookingId: null, publicId: "reservation:veedufix/booking-diagnostics/customer-1/diagnostic-pending", expiresAt: claimExpiresAt }
    });
  });
    it("validates optional booking photo IDs and rejects duplicate or over-limit lists", () => {
    const base = { body: { items: [{ serviceId: "service-1" }], diagnosticPhotoIds: ["a", "b"], bookingType: "instant" }, params: {}, query: {} };
    expect(createPaymentOrderSchema.safeParse(base).success).toBe(true);
    expect(createPaymentOrderSchema.safeParse({ ...base, body: { ...base.body, diagnosticPhotoIds: ["a", "a"] } }).success).toBe(false);
    expect(createPaymentOrderSchema.safeParse({ ...base, body: { ...base.body, diagnosticPhotoIds: ["1", "2", "3", "4", "5", "6"] } }).success).toBe(false);
  });

  it("leaves booking creation unchanged when the Customer skips photos", async () => {
    const updateMany = vi.fn();
    await attachDiagnosticPhotosToBooking({ bookingDiagnosticPhoto: { updateMany } } as never, { userId: "customer-1", bookingId: "booking-1" });
    expect(updateMany).not.toHaveBeenCalled();
  });

  it("retains the uploaded asset identifier when database persistence and storage cleanup both fail", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.update).mockRejectedValueOnce(new Error("database unavailable"));
    vi.mocked(destroyAuthenticatedImage).mockRejectedValueOnce(new Error("storage unavailable"));

    await expect(uploadBookingDiagnosticPhoto({
      userId: "customer-1",
      clientUploadId: "upload-retry",
      file: validFile
    })).rejects.toThrow("database unavailable");

    expect(prisma.bookingDiagnosticPhoto.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ publicId: expect.stringMatching(/^reservation:/) }),
      data: expect.objectContaining({ publicId: "private/photo-1", expiresAt: expect.any(Date) })
    }));
    expect(prisma.bookingDiagnosticPhoto.deleteMany).not.toHaveBeenCalled();
  });

  it("removes its reservation when Cloudinary upload fails", async () => {
    vi.mocked(uploadBufferToCloudinary).mockRejectedValueOnce(new Error("storage unavailable"));
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile })).rejects.toThrow("storage unavailable");
    expect(prisma.bookingDiagnosticPhoto.create).toHaveBeenCalledOnce();
    expect(prisma.bookingDiagnosticPhoto.deleteMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ clientUploadId: "upload-1", publicId: expect.stringMatching(/^reservation:/) })
    }));
  });

  it("deletes the private Cloudinary asset if final database persistence fails", async () => {
    vi.mocked(prisma.bookingDiagnosticPhoto.update).mockRejectedValueOnce(new Error("database unavailable"));
    await expect(uploadBookingDiagnosticPhoto({ userId: "customer-1", clientUploadId: "upload-1", file: validFile })).rejects.toThrow("database unavailable");
    expect(destroyAuthenticatedImage).toHaveBeenCalledWith("private/photo-1");
  });
  it("attaches only owned, unexpired, unattached uploads in the booking transaction", async () => {
    const updateMany = vi.fn().mockResolvedValue({ count: 2 });
    await attachDiagnosticPhotosToBooking({ bookingDiagnosticPhoto: { updateMany } } as never, { userId: "customer-1", bookingId: "booking-1", photoIds: ["a", "b"] });
    expect(updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: expect.objectContaining({ uploadedById: "customer-1", bookingId: null, publicId: { not: { startsWith: "reservation:" } }, expiresAt: { gt: expect.any(Date) }, id: { in: ["a", "b"] } }),
      data: { bookingId: "booking-1", expiresAt: null }
    }));
  });

  it("rolls back booking creation if a photo is expired, owned by someone else, or already attached", async () => {
    const updateMany = vi.fn().mockResolvedValue({ count: 1 });
    await expect(attachDiagnosticPhotosToBooking({ bookingDiagnosticPhoto: { updateMany } } as never, { userId: "customer-1", bookingId: "booking-1", photoIds: ["a", "b"] })).rejects.toMatchObject({ statusCode: 409 });
  });
});
