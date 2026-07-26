import { Request, Response } from "express";
import {
  requestOtp,
  refreshSession,
  signInWithGoogle,
  signOut,
  verifyOtp
} from "./auth.service.js";

export async function requestOtpHandler(request: Request, response: Response): Promise<void> {
  const result = await requestOtp(request.body.channel, request.body.identifier);
  response.status(200).json({
    message: "OTP requested",
    ...result
  });
}

export async function verifyOtpHandler(request: Request, response: Response): Promise<void> {
  const result = await verifyOtp({
    channel: request.body.channel,
    identifier: request.body.identifier,
    otp: request.body.otp,
    role: request.body.role,
    name: request.body.name
  });

  response.status(200).json(result);
}

export async function refreshTokenHandler(request: Request, response: Response): Promise<void> {
  const result = await refreshSession(request.body.refreshToken);
  response.status(200).json(result);
}

export async function googleAuthHandler(request: Request, response: Response): Promise<void> {
  const result = await signInWithGoogle({
    idToken: request.body.idToken,
    role: request.body.role
  });
  response.status(200).json(result);
}

export async function signOutHandler(request: Request, response: Response): Promise<void> {
  await signOut(request.body.refreshToken);
  response.status(200).json({ message: "Signed out" });
}
