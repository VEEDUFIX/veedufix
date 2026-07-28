/**
 * mask-worker.ts
 *
 * Single source of truth for masking sensitive WorkerProfile financial fields
 * before they are serialized into any HTTP response.
 *
 * IMPORTANT: These helpers operate on data going TO the client only.
 * They must never be called on data that will be used internally (e.g. to
 * drive a Razorpay payout), because internal code needs the real values.
 */

/**
 * Masks an Aadhaar number so only the last 4 digits are visible.
 * e.g. "1234 5678 9012" → "XXXX-XXXX-9012"
 */
export function maskAadhaarNumber(value: string | null | undefined): string | null {
  if (!value) return null;
  const digits = value.replace(/\D/g, "");
  const last4 = digits.slice(-4).padStart(4, "0");
  return `XXXX-XXXX-${last4}`;
}

/**
 * Masks a bank account number so only the last 4 digits are visible.
 * e.g. "9876543210001234" → "XXXXXXXXXXXX1234"
 */
export function maskBankAccountNumber(value: string | null | undefined): string | null {
  if (!value) return null;
  const trimmed = value.trim();
  if (trimmed.length <= 4) return trimmed; // too short to mask meaningfully
  const last4 = trimmed.slice(-4);
  const mask = "X".repeat(trimmed.length - 4);
  return `${mask}${last4}`;
}

/**
 * Masks the local-part (before the @) of a UPI ID.
 * Keeps the first 2 characters and the @domain visible.
 * e.g. "abcdef@okhdfcbank" → "ab****@okhdfcbank"
 * e.g. "a@upi"             → "a@upi"  (single-char local-part, nothing to mask)
 */
export function maskUpiId(value: string | null | undefined): string | null {
  if (!value) return null;
  const atIndex = value.indexOf("@");
  if (atIndex <= 0) return value; // malformed or no @, return as-is
  const localPart = value.slice(0, atIndex);
  const domain = value.slice(atIndex); // includes the "@"
  if (localPart.length <= 2) return value; // too short to partially mask
  const visible = localPart.slice(0, 2);
  const masked = "*".repeat(localPart.length - 2);
  return `${visible}${masked}${domain}`;
}

/**
 * Returns a shallow copy of a WorkerProfile-like object with all sensitive
 * financial fields masked. bankIfsc is intentionally left unmasked — it is a
 * public bank branch code that carries no personal financial risk.
 *
 * Usage: call this on the worker object just before placing it inside any
 * HTTP response. Never call it on data that will be used for payout processing.
 */
export function maskWorkerFinancialFields<
  T extends {
    aadhaarNumber?: string | null;
    bankAccountNumber?: string | null;
    upiId?: string | null;
  }
>(worker: T): T {
  return {
    ...worker,
    aadhaarNumber: maskAadhaarNumber(worker.aadhaarNumber),
    bankAccountNumber: maskBankAccountNumber(worker.bankAccountNumber),
    upiId: maskUpiId(worker.upiId)
    // bankIfsc: intentionally NOT masked — it is a public bank branch code
  };
}
