import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.js';
import { UserRole } from '@prisma/client';
import * as quoteService from './custom-quote.service.js';
import { createCustomQuotePaymentOrder, verifyCustomQuotePayment } from './custom-quote-payment.service.js';

export async function requestCustomQuoteHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const booking = await quoteService.requestCustomQuote(
      req.params.bookingId as string,
      req.auth!.userId,
      req.body.notes
    );
    res.json({ booking });
  } catch (err) { next(err); }
}

export async function submitCustomQuoteHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const booking = await quoteService.submitCustomQuote(
      req.params.bookingId as string,
      req.auth!.userId,
      req.auth!.role as UserRole,
      req.body.amount,
      req.body.notes,
      req.body.itemized
    );
    res.json({ booking });
  } catch (err) { next(err); }
}

export async function respondCustomQuoteHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const booking = await quoteService.respondToCustomQuote(
      req.params.bookingId as string,
      req.auth!.userId,
      req.body.accept
    );
    res.json({ booking });
  } catch (err) { next(err); }
}

export async function getCustomQuoteHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const quote = await quoteService.getCustomQuote(
      req.params.bookingId as string,
      req.auth!.userId,
      req.auth!.role as UserRole
    );
    res.json({ quote });
  } catch (err) { next(err); }
}

export async function createCustomQuotePaymentOrderHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const payment = await createCustomQuotePaymentOrder(req.params.bookingId as string, req.auth!.userId);
    res.status(201).json(payment);
  } catch (err) { next(err); }
}

export async function verifyCustomQuotePaymentHandler(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  try {
    const result = await verifyCustomQuotePayment({
        bookingId: req.params.bookingId as string,
        customerId: req.auth!.userId,
        orderId: req.body.razorpayOrderId,
        paymentId: req.body.razorpayPaymentId,
        signature: req.body.razorpaySignature
      });
    res.json(result);
  } catch (err) { next(err); }
}