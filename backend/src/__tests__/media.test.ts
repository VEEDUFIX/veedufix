import { describe, it, expect, vi, beforeEach } from 'vitest';

// ─── Mocks ────────────────────────────────────────────────────────────────────
vi.mock('../lib/cloudinary.js', () => ({
  generateSignedUrl: vi.fn().mockReturnValue('https://res.cloudinary.com/test-cloud/image/authenticated/signed.jpg'),
  uploadBufferToCloudinary: vi.fn().mockResolvedValue({
    secure_url: 'https://cloudinary.com/image.jpg',
    public_id: 'public-id',
    bytes: 1024,
    format: 'jpg'
  })
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    workerProfile: { findUnique: vi.fn() },
    user: { update: vi.fn() },
    workerPortfolioPhoto: { findFirst: vi.fn(), create: vi.fn() },
    workerDocument: { create: vi.fn() },
  }
}));

// ─── Imports ──────────────────────────────────────────────────────────────────
import {
  uploadAvatarImage,
  uploadWorkerPortfolioImage,
  uploadWorkerDocumentImage
} from '../modules/media/media.service.js';
import { prisma } from '../lib/prisma.js';
import { uploadBufferToCloudinary } from '../lib/cloudinary.js';
import { AppError } from '../lib/app-error.js';

describe('Media Service', () => {
  const dummyFile = { buffer: Buffer.from('test'), size: 1024 } as any;

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('uploadAvatarImage', () => {
    it('uploads image and updates user', async () => {
      vi.mocked(prisma.user.update).mockResolvedValue({ id: 'u1', avatarUrl: 'https://cloudinary.com/image.jpg' } as any);
      
      const res = await uploadAvatarImage('u1', dummyFile);
      expect(res.avatarUrl).toBe('https://cloudinary.com/image.jpg');
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: 'u1' },
        data: { avatarUrl: 'https://cloudinary.com/image.jpg' }
      });
    });
  });

  describe('uploadWorkerPortfolioImage', () => {
    it('throws if worker profile not found', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue(null);
      await expect(uploadWorkerPortfolioImage('u1', dummyFile)).rejects.toThrow(AppError);
    });

    it('uploads image and creates portfolio photo', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'w1' } as any);
      vi.mocked(prisma.workerPortfolioPhoto.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.workerPortfolioPhoto.create).mockResolvedValue({
        id: 'p1', url: 'https://cloudinary.com/image.jpg', caption: 'Test', sortOrder: 1
      } as any);
      
      const res = await uploadWorkerPortfolioImage('u1', dummyFile, 'Test');
      expect(res.photo.url).toBe('https://cloudinary.com/image.jpg');
      expect(res.photo.caption).toBe('Test');
      expect(res.photo.sortOrder).toBe(1);
    });
  });

  describe('uploadWorkerDocumentImage', () => {
    it('uploads image and creates document', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'w1' } as any);
      vi.mocked(uploadBufferToCloudinary).mockResolvedValueOnce({
        secure_url: 'https://res.cloudinary.com/test-cloud/image/authenticated/v123/veedufix/documents/u1/document.jpg',
        public_id: 'public-id',
        bytes: 1024,
        format: 'jpg'
      } as any);
      vi.mocked(prisma.workerDocument.create).mockResolvedValue({
        id: 'd1', url: 'https://cloudinary.com/image.jpg', type: 'id_card'
      } as any);

      const res = await uploadWorkerDocumentImage('u1', dummyFile, 'id_card');
      expect(res.document.url).toBe('https://res.cloudinary.com/test-cloud/image/authenticated/v123/veedufix/documents/u1/document.jpg');
      expect(res.document.type).toBe('id_card');
      expect(vi.mocked(uploadBufferToCloudinary)).toHaveBeenCalledWith(
        dummyFile.buffer,
        expect.objectContaining({ type: 'authenticated' })
      );
      expect(prisma.workerDocument.create).toHaveBeenCalledWith(expect.objectContaining({
        data: expect.objectContaining({ publicId: 'public-id' })
      }));
    });
  });
});
