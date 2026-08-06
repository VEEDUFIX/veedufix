import { Request, Response } from "express";
import {
  listAuthSessions,
  revokeAllAuthSessions,
  revokeAuthSession,
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
    name: request.body.name,
    referralCode: request.body.referralCode
  });

  response.status(200).json(result);
}

export async function refreshTokenHandler(request: Request, response: Response): Promise<void> {
  const result = await refreshSession(request.body.refreshToken);
  response.status(200).json(result);
}

export async function googleAuthHandler(request: Request, response: Response): Promise<void> {
  const result = await signInWithGoogle({
    idToken: request.body.idToken
  });
  response.status(200).json(result);
}

export async function signOutHandler(request: Request, response: Response): Promise<void> {
  await signOut(request.body.refreshToken);
  response.status(200).json({ message: "Signed out" });
}

export async function listSessionsHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as Request & { auth?: { userId: string; sessionId: string } }).auth;
  if (!auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  const sessions = await listAuthSessions(auth.userId, auth.sessionId);
  response.status(200).json({ sessions });
}

export async function revokeSessionHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as Request & { auth?: { userId: string; sessionId: string } }).auth;
  if (!auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  await revokeAuthSession(auth.userId, String(request.params.sessionId));
  response.status(200).json({ message: "Session revoked" });
}

export async function revokeAllSessionsHandler(request: Request, response: Response): Promise<void> {
  const auth = (request as Request & { auth?: { userId: string; sessionId: string } }).auth;
  if (!auth) {
    response.status(401).json({ message: "Authentication required" });
    return;
  }

  await revokeAllAuthSessions(auth.userId, auth.sessionId);
  response.status(200).json({ message: "Other sessions revoked" });
}
