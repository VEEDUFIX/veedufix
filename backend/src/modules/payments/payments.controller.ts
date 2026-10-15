import { Request, Response } from "express";
import { createPaymentOrder, getPaymentOrderStatus, verifyPayment } from "./payments.service.js";

export async function paymentOrderStatusHandler(request: Request, response: Response): Promise<void> {
  const authRequest = request as Request & { auth?: { userId: string } };
  if (!authRequest.auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const bookingId = request.params.bookingId;
  const orderId = request.params.orderId;
  if (typeof bookingId !== "string" || typeof orderId !== "string") {
    response.status(400).json({ message: "Invalid payment order reference" });
    return;
  }

  const status = await getPaymentOrderStatus({
    userId: authRequest.auth.userId,
    bookingId,
    razorpayOrderId: orderId
  });
  response.status(200).json({ status });
}

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
    addressId: request.body.addressId,
    maintenanceOccurrenceId: request.body.maintenanceOccurrenceId,
    idempotencyKey: request.body.idempotencyKey,
    items: request.body.items,
    couponCode: request.body.couponCode,
    bookingType: request.body.bookingType,
    scheduledFor: request.body.scheduledFor,
    diagnosticPhotoIds: request.body.diagnosticPhotoIds
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
