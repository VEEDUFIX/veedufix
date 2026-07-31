import { releaseWorkerPayout as releaseRecordedPayout } from "../payout/payout.service.js";

export async function releaseWorkerPayout(bookingId: string): Promise<void> {
  await releaseRecordedPayout(bookingId);
}
