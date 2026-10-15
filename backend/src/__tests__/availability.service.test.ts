import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Prisma } from '@prisma/client';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/prisma.js', () => ({
  prisma: {
    workerProfile: { findUnique: vi.fn() },
    savedAddress: { findFirst: vi.fn() },
    address: { findFirst: vi.fn() },
    city: { findFirst: vi.fn() },
    serviceArea: { findFirst: vi.fn() },
    service: { findMany: vi.fn() },
    workerAvailability: { deleteMany: vi.fn(), createMany: vi.fn(), findMany: vi.fn() },
    booking: { findMany: vi.fn() },
    jobExecution: { findMany: vi.fn() },
    $transaction: vi.fn((cb) => cb(prismaMockTx)),
  },
}));

vi.mock('../modules/service-area/service-area.service.js', () => ({
  assertServiceablePincode: vi.fn()
}));
vi.mock('../modules/matching/matching.service.js', () => ({
  previewCustomerScheduleSlots: vi.fn()
}));

const prismaMockTx = {
  workerAvailability: { deleteMany: vi.fn(), createMany: vi.fn(), findMany: vi.fn() },
};

// ─── Imports ──────────────────────────────────────────────────────────────────

import {
  getWorkerProfileIdByUserId,
  setWeeklyAvailability,
  getWorkerAvailability,
  isWorkerAvailableAt,
  getCustomerScheduleSlots,
  WorkerAvailabilityNotFoundError
} from '../modules/availability/availability.service.js';
import { prisma } from '../lib/prisma.js';
import { assertServiceablePincode } from '../modules/service-area/service-area.service.js';
import { previewCustomerScheduleSlots } from '../modules/matching/matching.service.js';

describe('Availability Service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getWorkerProfileIdByUserId', () => {
    it('returns worker profile id', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'w1' } as any);
      const res = await getWorkerProfileIdByUserId('u1');
      expect(res).toBe('w1');
    });

    it('throws WorkerAvailabilityNotFoundError if not found', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue(null);
      await expect(getWorkerProfileIdByUserId('invalid')).rejects.toThrow(WorkerAvailabilityNotFoundError);
    });
  });

  describe('setWeeklyAvailability', () => {
    it('sets weekly availability and returns sorted slots', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'w1' } as any);
      
      const mockSlots = [
        { dayOfWeek: 1, startTime: '09:00', endTime: '17:00' }
      ];
      prismaMockTx.workerAvailability.findMany.mockResolvedValue(mockSlots as any);

      const res = await setWeeklyAvailability('w1', mockSlots);
      
      expect(prismaMockTx.workerAvailability.deleteMany).toHaveBeenCalledWith({ where: { workerId: 'w1' } });
      expect(prismaMockTx.workerAvailability.createMany).toHaveBeenCalledWith({
        data: [
          { workerId: 'w1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' }
        ]
      });
      expect(res[0].startTime).toBe('09:00');
    });
  });

  describe('getWorkerAvailability', () => {
    it('returns worker availability', async () => {
      vi.mocked(prisma.workerProfile.findUnique).mockResolvedValue({ id: 'w1' } as any);
      
      const mockSlots = [
        { dayOfWeek: 1, startTime: '09:00', endTime: '17:00' }
      ];
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue(mockSlots as any);

      const res = await getWorkerAvailability('w1');
      expect(res[0].dayOfWeek).toBe(1);
      expect(res[0].startTime).toBe('09:00');
    });
  });

  describe('isWorkerAvailableAt', () => {
    it('returns false if not in a working slot', async () => {
      // 10:00 AM on Sunday (day 0)
      const dateTime = new Date('2024-01-07T10:00:00Z');
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue([] as any);

      const isAvailable = await isWorkerAvailableAt('w1', dateTime);
      expect(isAvailable).toBe(false);
    });

    it('returns false if inside slot but has booking conflict', async () => {
      const dateTime = new Date('2024-01-08T10:00:00Z'); // Monday 10am
      
      // Inside slot
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue([
        { dayOfWeek: dateTime.getDay(), startTime: '09:00', endTime: '17:00' }
      ] as any);

      // Has conflict
      vi.mocked(prisma.booking.findMany).mockResolvedValue([{ id: 'b1' }] as any);
      vi.mocked(prisma.jobExecution.findMany).mockResolvedValue([{ id: 'j1' }] as any);

      const isAvailable = await isWorkerAvailableAt('w1', dateTime);
      expect(isAvailable).toBe(false);
    });

    it('returns true if inside slot and no conflict', async () => {
      const dateTime = new Date('2024-01-08T10:00:00Z'); // Monday 10am
      
      // Inside slot
      vi.mocked(prisma.workerAvailability.findMany).mockResolvedValue([
        { dayOfWeek: dateTime.getDay(), startTime: '09:00', endTime: '17:00' }
      ] as any);

      // No conflict
      vi.mocked(prisma.booking.findMany).mockResolvedValue([] as any);

      const isAvailable = await isWorkerAvailableAt('w1', dateTime);
      expect(isAvailable).toBe(true);
    });
  });

  describe('getCustomerScheduleSlots', () => {
    it('rejects booking addresses with missing coordinates instead of treating null as zero', async () => {
      vi.mocked(prisma.savedAddress.findFirst).mockResolvedValue(null);
      vi.mocked(prisma.address.findFirst).mockResolvedValue({
        pincode: '600001',
        latitude: null,
        longitude: null,
        city: { id: 'city-1', name: 'Chennai' }
      } as any);
      vi.mocked(assertServiceablePincode).mockResolvedValue({ serviceAreaIds: ['area-1'] } as any);
      vi.mocked(prisma.service.findMany).mockResolvedValue([{
        id: 'service-1',
        categoryId: 'category-1',
        availabilityMode: 'CUSTOM',
        serviceAreaAssignments: [{ serviceAreaId: 'area-1' }],
        subcategory: {
          availabilityMode: 'CUSTOM',
          serviceAreaAssignments: [{ serviceAreaId: 'area-1' }],
          category: {
            availabilityMode: 'CUSTOM',
            serviceAreaAssignments: [{ serviceAreaId: 'area-1' }]
          }
        }
      }] as any);

      await expect(getCustomerScheduleSlots({
        userId: 'customer-1',
        addressId: 'address-1',
        serviceIds: ['service-1'],
        startDate: '2026-10-16',
        days: 7
      })).rejects.toMatchObject({
        statusCode: 400,
        message: 'Add a map location to this address before scheduling a booking'
      });

      expect(previewCustomerScheduleSlots).not.toHaveBeenCalled();
    });
  });
});
