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
    const { default: admin } = await import("firebase-admin") as any;

    if (!admin.apps || admin.apps.length === 0) {
      const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (serviceAccountEnv) {
        admin.initializeApp({ credential: admin.credential.cert(JSON.parse(serviceAccountEnv)) });
      } else {
        admin.initializeApp({ credential: admin.credential.applicationDefault() });
      }
    }

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
