import { env } from "./env.js";

async function firebaseAdmin() {
  const { default: admin } = await import("firebase-admin") as any;

  if (!admin.apps || admin.apps.length === 0) {
    const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const credential = serviceAccountEnv
      ? admin.credential.cert(JSON.parse(serviceAccountEnv))
      : admin.credential.cert({
          projectId: env.FIREBASE_PROJECT_ID,
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
        });
    admin.initializeApp({ credential });
  }

  return admin;
}

export async function verifyFirebaseIdToken(idToken: string): Promise<{ uid: string; phoneNumber?: string }> {
  const admin = await firebaseAdmin();
  const claims = await admin.auth().verifyIdToken(idToken);
  return { uid: claims.uid, phoneNumber: claims.phone_number };
}

export async function sendPushNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, unknown>
): Promise<{ successCount: number; failureCount: number }> {
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0 };
  }

  try {
    const admin = await firebaseAdmin();

    const message = {
      tokens,
      notification: {
        title,
        body
      },
      data:
        data != null
          ? Object.fromEntries(
              Object.entries(data).map(([key, value]) => [key, String(value)])
            )
          : undefined
    };

    const result = await admin.messaging().sendEachForMulticast(message);
    return {
      successCount: result.successCount,
      failureCount: result.failureCount
    };
  } catch {
    return { successCount: 0, failureCount: tokens.length };
  }
}
