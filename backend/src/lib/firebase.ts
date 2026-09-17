import { env } from "../config/env.js";
import { AppError } from "./app-error.js";

export async function verifyGoogleIdToken(idToken: string): Promise<{
  sub: string;
  email?: string;
  name?: string;
  picture?: string;
}> {
  if (!env.GOOGLE_SERVER_CLIENT_ID) {
    throw AppError.serviceUnavailable("Google sign-in is not configured on the server");
  }

  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  if (!response.ok) {
    throw AppError.unauthorized("Unable to verify Google account");
  }

  const decoded = (await response.json()) as {
    aud?: string;
    sub?: string;
    email?: string;
    email_verified?: string;
    name?: string;
    picture?: string;
  };

  if (decoded.aud !== env.GOOGLE_SERVER_CLIENT_ID) {
    throw AppError.unauthorized("Google account is not configured for this app");
  }

  if (!decoded.sub) {
    throw AppError.unauthorized("Google account response is incomplete");
  }

  if (decoded.email && decoded.email_verified !== "true") {
    throw AppError.unauthorized("Google email is not verified");
  }

  return {
    sub: decoded.sub,
    email: decoded.email,
    name: decoded.name,
    picture: decoded.picture
  };
}
