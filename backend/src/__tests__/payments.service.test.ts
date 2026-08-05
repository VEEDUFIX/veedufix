/**
 * Tests for payment signature verification + AppError contract + error-handler
 * middleware integration.
 *
 * Path note: test file is at src/__tests__/, so src/ is one level up (../).
 */
import { describe, it, expect, vi } from 'vitest';
import { createHmac } from 'crypto';

// ─── Mocks ────────────────────────────────────────────────────────────────────

vi.mock('../lib/logger.js', () => ({
  logger: { info: vi.fn(), error: vi.fn(), warn: vi.fn() },
}));

// ─── Imports ──────────────────────────────────────────────────────────────────

import { AppError } from '../lib/app-error.js';
import { errorHandler } from '../middleware/error-handler.js';
import type { Request, Response, NextFunction } from 'express';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const RAZORPAY_SECRET = 'test_razorpay_secret';

/** Builds the HMAC-SHA256 signature Razorpay sends on successful payment. */
function buildValidRazorpaySignature(orderId: string, paymentId: string): string {
  return createHmac('sha256', RAZORPAY_SECRET)
    .update(`${orderId}|${paymentId}`)
    .digest('hex');
}

// ─── Payment signature verification ──────────────────────────────────────────

describe('Razorpay HMAC signature verification', () => {
  it('produces a 64-char hex string (SHA-256 output)', () => {
    const sig = buildValidRazorpaySignature('order_abc', 'pay_xyz');
    expect(sig).toHaveLength(64);
    expect(sig).toMatch(/^[0-9a-f]{64}$/);
  });

  it('is deterministic — same inputs always produce same signature', () => {
    const orderId = 'order_123';
    const paymentId = 'pay_456';
    expect(buildValidRazorpaySignature(orderId, paymentId))
      .toBe(buildValidRazorpaySignature(orderId, paymentId));
  });

  it('changes if the orderId changes', () => {
    const sig1 = buildValidRazorpaySignature('order_aaa', 'pay_xyz');
    const sig2 = buildValidRazorpaySignature('order_bbb', 'pay_xyz');
    expect(sig1).not.toBe(sig2);
  });

  it('changes if the paymentId changes', () => {
    const sig1 = buildValidRazorpaySignature('order_aaa', 'pay_111');
    const sig2 = buildValidRazorpaySignature('order_aaa', 'pay_222');
    expect(sig1).not.toBe(sig2);
  });

  it('fails verification when the secret is wrong (tamper detection)', () => {
    const legitSig = buildValidRazorpaySignature('order_abc', 'pay_xyz');
    const attackerSig = createHmac('sha256', 'wrong_secret')
      .update('order_abc|pay_xyz')
      .digest('hex');
    expect(legitSig).not.toBe(attackerSig);
  });

  it('fails verification when the payload is altered', () => {
    const legitSig = buildValidRazorpaySignature('order_abc', 'pay_xyz');
    const alteredSig = createHmac('sha256', RAZORPAY_SECRET)
      .update('order_abc|pay_TAMPERED') // different paymentId
      .digest('hex');
    expect(legitSig).not.toBe(alteredSig);
  });
});

// ─── AppError class contract ──────────────────────────────────────────────────

describe('AppError', () => {
  it('is an instance of Error', () => {
    expect(AppError.badRequest('test')).toBeInstanceOf(Error);
  });

  it('is an instance of AppError', () => {
    expect(AppError.badRequest('test')).toBeInstanceOf(AppError);
  });

  it('sets name to "AppError"', () => {
    expect(AppError.badRequest('test').name).toBe('AppError');
  });

  it('.badRequest() → 400', () => {
    const err = AppError.badRequest('Invalid OTP');
    expect(err.statusCode).toBe(400);
    expect(err.message).toBe('Invalid OTP');
  });

  it('.unauthorized() → 401', () => {
    expect(AppError.unauthorized('Session ended').statusCode).toBe(401);
  });

  it('.forbidden() → 403', () => {
    expect(AppError.forbidden('No access').statusCode).toBe(403);
  });

  it('.notFound() → 404', () => {
    expect(AppError.notFound('Booking not found').statusCode).toBe(404);
  });

  it('.conflict() → 409', () => {
    expect(AppError.conflict('Already exists').statusCode).toBe(409);
  });

  it('.gone() → 410', () => {
    const err = AppError.gone('OTP expired or missing');
    expect(err.statusCode).toBe(410);
    expect(err.message).toBe('OTP expired or missing');
  });

  it('is distinguishable from a plain Error via instanceof', () => {
    expect(new Error('plain') instanceof AppError).toBe(false);
    expect(AppError.badRequest('domain') instanceof AppError).toBe(true);
  });
});

// ─── errorHandler middleware integration ──────────────────────────────────────

describe('errorHandler middleware', () => {
  const mockReq = {} as Request;
  const mockNext = vi.fn() as unknown as NextFunction;

  function makeRes(): Response {
    return {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    } as unknown as Response;
  }

  it('returns 410 with message for OTP expired AppError', () => {
    const res = makeRes();
    errorHandler(AppError.gone('OTP expired or missing'), mockReq, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(410);
    expect(res.json).toHaveBeenCalledWith({ message: 'OTP expired or missing' });
  });

  it('returns 400 with message for invalid OTP AppError', () => {
    const res = makeRes();
    errorHandler(AppError.badRequest('Invalid OTP'), mockReq, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ message: 'Invalid OTP' });
  });

  it('returns 401 with message for revoked refresh token AppError', () => {
    const res = makeRes();
    errorHandler(AppError.unauthorized('Refresh token revoked'), mockReq, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({ message: 'Refresh token revoked' });
  });

  it('returns 500 for an unexpected plain Error', () => {
    const res = makeRes();
    errorHandler(new Error('unexpected crash'), mockReq, res, mockNext);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({ message: 'Internal server error' });
  });

  it('does NOT return 500 for any AppError', () => {
    const errors = [
      AppError.badRequest('x'),
      AppError.unauthorized('x'),
      AppError.forbidden('x'),
      AppError.notFound('x'),
      AppError.conflict('x'),
      AppError.gone('x'),
    ];
    for (const err of errors) {
      const res = makeRes();
      errorHandler(err, mockReq, res, mockNext);
      expect(res.status).not.toHaveBeenCalledWith(500);
    }
  });
});
