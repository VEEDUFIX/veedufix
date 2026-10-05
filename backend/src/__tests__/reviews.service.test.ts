import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  bookingFindUnique: vi.fn(),
  reviewFindUnique: vi.fn(),
  reviewCreate: vi.fn(),
  reviewFindMany: vi.fn(),
  workerProfileUpdate: vi.fn(),
}));

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    booking: { findUnique: mocks.bookingFindUnique },
    review: {
      findUnique: mocks.reviewFindUnique,
      create: mocks.reviewCreate,
      findMany: mocks.reviewFindMany,
    },
    workerProfile: { update: mocks.workerProfileUpdate },
  },
}));

import { AppError } from '../lib/app-error.js';
import { submitReview } from '../modules/reviews/reviews.service.js';

describe('submitReview eligibility', () => {
  beforeEach(() => vi.clearAllMocks());

  it('rejects invalid ratings before loading the booking', async () => {
    await expect(submitReview({
      bookingId: 'booking-1', reviewerId: 'customer-1', rating: 0,
    })).rejects.toMatchObject({ statusCode: 400 } satisfies Partial<AppError>);
    expect(mocks.bookingFindUnique).not.toHaveBeenCalled();
  });

  it('rejects comments over 500 characters before loading the booking', async () => {
    await expect(submitReview({
      bookingId: 'booking-1', reviewerId: 'customer-1', rating: 5,
      comment: 'x'.repeat(501),
    })).rejects.toMatchObject({ statusCode: 400 } satisfies Partial<AppError>);
    expect(mocks.bookingFindUnique).not.toHaveBeenCalled();
  });

  it('rejects reviews until the booking is completed', async () => {
    mocks.bookingFindUnique.mockResolvedValue({
      id: 'booking-1', customerId: 'customer-1', workerId: 'worker-1', status: 'IN_PROGRESS',
    });

    await expect(submitReview({
      bookingId: 'booking-1', reviewerId: 'customer-1', rating: 5,
    })).rejects.toMatchObject({ statusCode: 409 } satisfies Partial<AppError>);
    expect(mocks.reviewCreate).not.toHaveBeenCalled();
  });

  it('does not allow a different customer to review a completed booking', async () => {
    mocks.bookingFindUnique.mockResolvedValue({
      id: 'booking-1', customerId: 'customer-1', workerId: 'worker-1', status: 'COMPLETED',
    });

    await expect(submitReview({
      bookingId: 'booking-1', reviewerId: 'customer-2', rating: 5,
    })).rejects.toMatchObject({ statusCode: 403 });
    expect(mocks.reviewCreate).not.toHaveBeenCalled();
  });

  it('allows the booking customer to review after completion', async () => {
    mocks.bookingFindUnique.mockResolvedValue({
      id: 'booking-1', customerId: 'customer-1', workerId: 'worker-1', status: 'COMPLETED',
    });
    mocks.reviewFindUnique.mockResolvedValue(null);
    mocks.reviewCreate.mockResolvedValue({ id: 'review-1', rating: 5 });
    mocks.reviewFindMany.mockResolvedValue([{ rating: 5 }]);
    mocks.workerProfileUpdate.mockResolvedValue({});

    await expect(submitReview({
      bookingId: 'booking-1', reviewerId: 'customer-1', rating: 5,
      comment: '  Great service!  ',
    })).resolves.toMatchObject({ id: 'review-1' });
    expect(mocks.reviewCreate).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ comment: 'Great service!' }),
    }));
    expect(mocks.workerProfileUpdate).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 'worker-1' },
      data: { averageRating: 5 },
    }));
  });
});
