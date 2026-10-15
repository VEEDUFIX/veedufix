import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requireRole } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import {
  requestCustomQuoteSchema,
  submitCustomQuoteSchema,
  respondCustomQuoteSchema
} from './custom-quote.schemas.js';
import {
  requestCustomQuoteHandler,
  submitCustomQuoteHandler,
  respondCustomQuoteHandler,
  getCustomQuoteHandler,
  createCustomQuotePaymentOrderHandler,
  verifyCustomQuotePaymentHandler
} from './custom-quote.controller.js';

export const customQuoteRouter = Router();

customQuoteRouter.post(
  '/bookings/:bookingId/custom-quote/request',
  requireAuth,
  requireRole('CUSTOMER'),
  validate(requestCustomQuoteSchema),
  requestCustomQuoteHandler
);

customQuoteRouter.post(
  '/bookings/:bookingId/custom-quote/submit',
  requireAuth,
  requireRole('WORKER', 'ADMIN'),
  validate(submitCustomQuoteSchema),
  submitCustomQuoteHandler
);

customQuoteRouter.post(
  '/bookings/:bookingId/custom-quote/respond',
  requireAuth,
  requireRole('CUSTOMER'),
  validate(respondCustomQuoteSchema),
  respondCustomQuoteHandler
);

customQuoteRouter.get(
  '/bookings/:bookingId/custom-quote',
  requireAuth,
  getCustomQuoteHandler
);

customQuoteRouter.post('/bookings/:bookingId/custom-quote/payment-order', requireAuth, requireRole('CUSTOMER'), createCustomQuotePaymentOrderHandler);
customQuoteRouter.post('/bookings/:bookingId/custom-quote/verify-payment', requireAuth, requireRole('CUSTOMER'), validate(z.object({ body: z.object({ razorpayOrderId: z.string().min(1), razorpayPaymentId: z.string().min(1), razorpaySignature: z.string().min(1) }).strict(), params: z.object({ bookingId: z.string().min(1) }), query: z.object({}).strict() })), verifyCustomQuotePaymentHandler);