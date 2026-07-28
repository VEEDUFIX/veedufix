/**
 * Test script: Verify that raiseOpsAlert creates an OpsAlert record
 * with type='payment_mismatch' and severity='critical'.
 *
 * Run: npx tsx scripts/test-payment-mismatch-alert.ts
 */
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("=== Payment Mismatch Alert Integration Test ===\n");

  // 1. Import and call raiseOpsAlert directly (same path as flagPaymentAmountMismatch)
  const { raiseOpsAlert } = await import("../src/modules/ops/ops.service.js");

  const testSourceId = `payment_mismatch:test_payment_${Date.now()}`;
  const testBookingId = "test_booking_id_12345";

  console.log("1. Calling raiseOpsAlert with type=payment_mismatch...");
  const alert = await raiseOpsAlert({
    type: "payment_mismatch",
    sourceId: testSourceId,
    bookingId: testBookingId,
    severity: "critical",
    message: "Payment amount mismatch on booking TEST-001: expected 79900p, got 50000p from Razorpay.",
    metadata: {
      title: "Payment mismatch \u2014 TEST-001",
      bookingCode: "TEST-001",
      expectedAmountPaise: 79900,
      actualCapturedAmountPaise: 50000,
      amount: 500.00,
      timestamp: new Date().toISOString(),
      retryAvailable: false
    }
  });

  console.log("   raiseOpsAlert returned:", JSON.stringify(alert, null, 2));

  // 2. Verify the record exists in the database
  console.log("\n2. Querying OpsAlert table directly...");
  const dbRecord = await prisma.opsAlert.findUnique({
    where: { sourceId: testSourceId }
  });

  if (!dbRecord) {
    console.error("   FAIL: No OpsAlert record found with sourceId:", testSourceId);
    process.exit(1);
  }

  console.log("   Record found in database:");
  console.log("     id:", dbRecord.id);
  console.log("     type:", dbRecord.type);
  console.log("     severity:", dbRecord.severity);
  console.log("     status:", dbRecord.status);
  console.log("     bookingId:", dbRecord.bookingId);
  console.log("     message:", dbRecord.message);
  console.log("     metadata:", JSON.stringify(dbRecord.metadata, null, 2));
  console.log("     createdAt:", dbRecord.createdAt.toISOString());

  // 3. Verify type and severity
  const typeOk = dbRecord.type === "payment_mismatch";
  const severityOk = dbRecord.severity === "critical";
  const statusOk = dbRecord.status === "open";

  console.log("\n3. Assertions:");
  console.log(`   type === 'payment_mismatch': ${typeOk ? "PASS" : "FAIL"} (got '${dbRecord.type}')`);
  console.log(`   severity === 'critical':     ${severityOk ? "PASS" : "FAIL"} (got '${dbRecord.severity}')`);
  console.log(`   status === 'open':           ${statusOk ? "PASS" : "FAIL"} (got '${dbRecord.status}')`);

  // 4. Verify via listOpsAlerts (same function the API endpoint uses)
  console.log("\n4. Verifying via listOpsAlerts (same as GET /admin/alerts)...");
  const { listOpsAlerts } = await import("../src/modules/ops/ops.service.js");
  const alertsPage = await listOpsAlerts({ type: "payment_mismatch", status: "open" });

  const foundInList = alertsPage.items.some((a: { id: string }) => a.id === dbRecord.id);
  console.log(`   Alert appears in listOpsAlerts response: ${foundInList ? "PASS" : "FAIL"}`);
  console.log(`   Total payment_mismatch alerts (open): ${alertsPage.total}`);

  // 5. Cleanup
  console.log("\n5. Cleaning up test record...");
  await prisma.opsAlert.delete({ where: { id: dbRecord.id } });
  console.log("   Deleted test OpsAlert record.");

  const allPassed = typeOk && severityOk && statusOk && foundInList;
  console.log(`\n=== ${allPassed ? "ALL TESTS PASSED" : "SOME TESTS FAILED"} ===`);

  if (!allPassed) {
    process.exit(1);
  }
}

main()
  .catch((error) => {
    console.error("Test failed with error:", error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
