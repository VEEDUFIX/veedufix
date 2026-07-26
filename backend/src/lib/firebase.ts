import admin from "firebase-admin";
import { env } from "../config/env.js";

let initialized = false;

function initializeFirebase(): void {
  if (initialized) {
    return;
  }

  if (!env.FIREBASE_PROJECT_ID || !env.FIREBASE_CLIENT_EMAIL || !env.FIREBASE_PRIVATE_KEY) {
    throw new Error("Firebase credentials are not configured");
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.FIREBASE_PROJECT_ID,
      clientEmail: env.FIREBASE_CLIENT_EMAIL,
      privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
    })
  });

  initialized = true;
}

export async function verifyGoogleIdToken(idToken: string): Promise<{
  email?: string;
  name?: string;
  picture?: string;
}> {
  initializeFirebase();
  const decoded = await admin.auth().verifyIdToken(idToken, true);
  return {
    email: decoded.email,
    name: decoded.name,
    picture: decoded.picture
  };
}
