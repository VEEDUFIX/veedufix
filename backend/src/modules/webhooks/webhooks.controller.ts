import { Request, Response } from "express";
import { handleRazorpayWebhook } from "./webhooks.service.js";

type RequestWithRawBody = Request & {
  rawBody?: string;
};

export async function razorpayWebhookHandler(request: Request, response: Response): Promise<void> {
  const typedRequest = request as RequestWithRawBody;
  const signature = request.header("x-razorpay-signature") ?? undefined;

  try {
    await handleRazorpayWebhook(
      typedRequest.rawBody ?? JSON.stringify(request.body ?? {}),
      signature,
      request.body
    );
    response.status(200).json({ ok: true });
  } catch (error) {
    response.status(400).json({
      message: error instanceof Error ? error.message : "Webhook processing failed"
    });
  }
}

export async function razorpayxWebhookHandler(request: Request, response: Response): Promise<void> {
  await razorpayWebhookHandler(request, response);
}
