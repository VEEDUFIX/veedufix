import { PrismaClient } from '@prisma/client';
import { raiseDispute, resolveDispute } from './src/modules/dispute/dispute.service.js';

const prisma = new PrismaClient();

async function runSimulation() {
  console.log('--- Starting Dispute Flow Simulation ---\n');

  // Cleanup past failed runs
  await prisma.dispute.deleteMany({ where: { bookingId: 'BKG-TEST-123' }});
  await prisma.bookingTimelineEvent.deleteMany({ where: { bookingId: 'BKG-TEST-123' }});
  await prisma.bookingService.deleteMany({ where: { bookingId: 'BKG-TEST-123' }});
  await prisma.booking.deleteMany({ where: { id: 'BKG-TEST-123' }});
  await prisma.user.deleteMany({ where: { phone: { in: ['+919999999999', '+918888888888'] } }});

  // 1. Setup Data
  console.log('[1/6] Creating test data...');
  const user = await prisma.user.create({
    data: {
      phone: '+919999999999',
      name: 'Test Customer',
      role: 'CUSTOMER'
    }
  });

  const worker = await prisma.user.create({
    data: {
      phone: '+918888888888',
      name: 'Test Worker',
      role: 'WORKER',
      workerProfile: {
        create: {
          workerStatus: 'ACTIVE',
        }
      }
    }
  });

  const booking = await prisma.booking.create({
    data: {
      id: 'BKG-TEST-123',
      userId: user.id,
      assignedWorkerId: worker.id,
      status: 'COMPLETED',
      totalAmount: 1500,
      paymentStatus: 'PAID',
      serviceAddress: { city: 'Chennai', pincode: '600001', lat: 13, lng: 80, addressLine1: 'Test' },
      services: { create: [{ serviceId: 'srv-1', name: 'Test Service', price: 1500, quantity: 1, basePrice: 1500 }] },
      completedAt: new Date(),
      timeline: {
        create: [
          { status: 'CONFIRMED', description: 'Booking confirmed' },
          { status: 'COMPLETED', description: 'Job completed' }
        ]
      }
    }
  });

  console.log(`✓ Created completed Booking: ${booking.id} at ${booking.completedAt}`);

  // 2. Simulate standard payout releaser (less than 48 hours, should NOT release)
  console.log('\n[2/6] Running payout-releaser (Right after completion)...');
  const now = new Date();
  const threshold = new Date(now.getTime() - 48 * 60 * 60 * 1000);
  
  const eligibleBookings = await prisma.booking.findMany({
    where: {
      status: 'COMPLETED',
      completedAt: { lte: threshold, not: null },
      payoutStatus: 'PENDING',
      disputes: { none: { status: 'OPEN' } },
    }
  });
  console.log(`Found ${eligibleBookings.length} eligible bookings for payout. (Expected 0 since 48h hasn't passed)`);


  // 3. Customer Raises a Dispute
  console.log('\n[3/6] Customer raises a dispute (within 48 hours)...');
  const dispute = await raiseDispute(user.id, booking.id, {
    reason: 'WORKER_NO_SHOW',
    description: 'Worker did not complete the job properly, left a mess.',
  });
  console.log(`✓ Dispute created: ${dispute.id} with status: ${dispute.status}`);


  // 4. Simulate standard payout releaser after 48 hours (Should skip because dispute is open)
  console.log('\n[4/6] Running payout-releaser after 48 hours (Dispute is OPEN)...');
  
  // Fast forward booking completion time by 3 days
  await prisma.booking.update({
    where: { id: booking.id },
    data: { completedAt: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000) }
  });

  const threshold2 = new Date(Date.now() - 48 * 60 * 60 * 1000);
  const eligibleBookings2 = await prisma.booking.findMany({
    where: {
      status: 'COMPLETED',
      completedAt: { lte: threshold2, not: null },
      payoutStatus: 'PENDING',
      disputes: { none: { status: 'OPEN' } },
    }
  });
  console.log(`Found ${eligibleBookings2.length} eligible bookings for payout. (Expected 0 because dispute is OPEN)`);


  // 5. Admin Resolves Dispute (Refunds Customer)
  console.log('\n[5/6] Admin reviews and resolves dispute (Refunds customer)...');
  await resolveDispute(dispute.id, {
    adminId: 'admin-uuid',
    resolution: 'refund',
    resolutionNote: 'Customer provided photos of incomplete work. Refunding full amount.',
    refundAmount: 1500
  });
  
  const resolvedDispute = await prisma.dispute.findUnique({ where: { id: dispute.id }});
  const updatedBooking = await prisma.booking.findUnique({ where: { id: booking.id }});
  
  console.log(`✓ Dispute Status: ${resolvedDispute?.status} (Expected: RESOLVED)`);
  console.log(`✓ Dispute Resolution: ${resolvedDispute?.resolution} (Expected: REFUNDED)`);
  console.log(`✓ Booking Status: ${updatedBooking?.status} (Expected: CANCELLED or similar depending on refund logic, or payoutStatus marked appropriately)`);


  // 6. Cleanup
  console.log('\n[6/6] Cleaning up test data...');
  await prisma.dispute.deleteMany({ where: { bookingId: booking.id }});
  await prisma.bookingTimeline.deleteMany({ where: { bookingId: booking.id }});
  await prisma.bookingItem.deleteMany({ where: { bookingId: booking.id }});
  await prisma.booking.deleteMany({ where: { id: booking.id }});
  await prisma.user.deleteMany({ where: { id: { in: [user.id, worker.id] } }});
  console.log('✓ Cleanup complete.');

  console.log('\n--- Simulation Complete ---');
}

runSimulation().catch(console.error).finally(() => prisma.$disconnect());
