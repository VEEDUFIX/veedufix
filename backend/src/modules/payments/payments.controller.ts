import { Request, Response } from "express";
import { createPaymentOrder, verifyPayment } from "./payments.service.js";

export async function createPaymentOrderHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as Request & {
    auth?: {
      userId: string;
    };
  };

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const result = await createPaymentOrder({
    userId: authRequest.auth.userId,
    cityId: request.body.cityId,
    items: request.body.items,
    couponCode: request.body.couponCode,
    bookingType: request.body.bookingType,
    scheduledFor: request.body.scheduledFor
  });

  response.status(201).json(result);
}

export async function verifyPaymentHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as Request & {
    auth?: {
      userId: string;
    };
  };

  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const result = await verifyPayment({
    userId: authRequest.auth.userId,
    bookingId: request.body.bookingId,
    razorpayOrderId: request.body.razorpayOrderId,
    razorpayPaymentId: request.body.razorpayPaymentId,
    razorpaySignature: request.body.razorpaySignature
  });

  response.status(200).json(result);
}
