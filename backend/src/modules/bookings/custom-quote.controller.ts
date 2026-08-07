import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.js';
import * as quoteService from './custom-quote.service.js';

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
      req.auth!.userId
    );
    res.json({ quote });
  } catch (err) { next(err); }
}
