import { Router } from 'express';
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
  getCustomQuoteHandler
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
