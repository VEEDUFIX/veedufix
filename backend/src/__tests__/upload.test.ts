import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('cloudinary', () => {
  return {
    v2: {
      config: vi.fn(),
      uploader: {
        destroy: vi.fn().mockResolvedValue({ result: 'ok' })
      },
      utils: {
        api_sign_request: vi.fn().mockReturnValue('mocked-signature')
      }
    }
  };
});

vi.mock('../config/env.js', () => ({
  env: {
    CLOUDINARY_CLOUD_NAME: 'test-cloud',
    CLOUDINARY_API_KEY: 'test-key',
    CLOUDINARY_API_SECRET: 'test-secret'
  }
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: vi.fn() },
    bookingTimelineEvent: { create: vi.fn() },
    notification: { create: vi.fn() }
  }
}));

vi.mock('../lib/cloudinary.js', () => ({
  uploadBufferToCloudinary: vi.fn().mockResolvedValue({
    secure_url: 'https://cloudinary.com/image.jpg',
    public_id: 'public-id',
    bytes: 1024,
    format: 'jpg'
  })
}));

vi.mock('../lib/realtime.js', () => ({
  publishNotificationEvent: vi.fn(),
  publishTrackingEvent: vi.fn()
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import {
  assertWorkerCanUploadJobPhoto,
  uploadJobPhoto,
  uploadAndRecordJobPhoto,
  deleteJobPhoto,
  generateUploadSignature,
  confirmJobPhotoUpload
} from '../modules/upload/upload.service.js';
import { prisma } from '../lib/prisma.js';
import { AppError } from '../lib/app-error.js';

describe('Upload Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('assertWorkerCanUploadJobPhoto', () => {
    it('throws if booking not found', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue(null);
      await expect(assertWorkerCanUploadJobPhoto('b1', 'u1')).rejects.toThrow(AppError);
    });

    it('throws if worker not assigned', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', worker: { userId: 'u2' }
      } as any);
      await expect(assertWorkerCanUploadJobPhoto('b1', 'u1')).rejects.toThrow(AppError);
    });

    it('passes if worker is assigned', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', worker: { userId: 'u1' }
      } as any);
      await expect(assertWorkerCanUploadJobPhoto('b1', 'u1')).resolves.toBeUndefined();
    });
  });

  describe('uploadJobPhoto', () => {
    it('uploads buffer to cloudinary', async () => {
      const res = await uploadJobPhoto(Buffer.from('test'), 'b1', 'before');
      expect(res.secureUrl).toBe('https://cloudinary.com/image.jpg');
      expect(res.publicId).toBe('public-id');
      expect(res.folder).toBe('veedufix/jobs/b1/before');
    });
  });

  describe('uploadAndRecordJobPhoto', () => {
    it('uploads and records timeline event', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: 'IN_PROGRESS', worker: { userId: 'u1' }
      } as any);
      vi.mocked(prisma.bookingTimelineEvent.create).mockResolvedValue({ id: 'tl1' } as any);
      
      const res = await uploadAndRecordJobPhoto(Buffer.from('test'), 'b1', 'u1', 'before');
      expect(res.secureUrl).toBe('https://cloudinary.com/image.jpg');
      expect(res.timelineEvent.id).toBe('tl1');
      expect(prisma.bookingTimelineEvent.create).toHaveBeenCalled();
      expect(prisma.notification.create).toHaveBeenCalled();
    });
  });

  describe('deleteJobPhoto', () => {
    it('deletes from cloudinary', async () => {
      const res = await deleteJobPhoto('public-id');
      expect(res.deleted).toBe(true);
      expect(res.publicId).toBe('public-id');
    });
  });

  describe('generateUploadSignature', () => {
    it('generates signature and params', async () => {
      const res = await generateUploadSignature('b1', 'before');
      expect(res.cloudName).toBe('test-cloud');
      expect(res.signature).toBe('mocked-signature');
      expect(res.folder).toBe('veedufix/jobs/b1/before');
    });
  });

  describe('confirmJobPhotoUpload', () => {
    it('records an already uploaded photo', async () => {
      vi.mocked(prisma.booking.findUnique).mockResolvedValue({
        id: 'b1', code: 'B-1', status: 'IN_PROGRESS', worker: { userId: 'u1' }
      } as any);
      
      const res = await confirmJobPhotoUpload('b1', 'u1', 'after', {
        secureUrl: 'url', publicId: 'pid', bytes: 100, format: 'png'
      });
      expect(res.notification.photoFolder).toBe('veedufix/jobs/b1/after');
    });
  });
});
