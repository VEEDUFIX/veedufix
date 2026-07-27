import { env } from "../config/env.js";

export async function verifyGoogleIdToken(idToken: string): Promise<{
  sub: string;
  email?: string;
  name?: string;
  picture?: string;
}> {
  if (!env.GOOGLE_SERVER_CLIENT_ID) {
    throw new Error("Google server client ID is not configured");
  }

  const response = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
  );
  if (!response.ok) {
    throw new Error("Unable to verify Google token");
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
    throw new Error("Google token audience mismatch");
  }

  if (!decoded.sub) {
    throw new Error("Google token is missing a subject");
  }

  if (decoded.email && decoded.email_verified !== "true") {
    throw new Error("Google email is not verified");
  }

  return {
    sub: decoded.sub,
    email: decoded.email,
    name: decoded.name,
    picture: decoded.picture
  };
}
