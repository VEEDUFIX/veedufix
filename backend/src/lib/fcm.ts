import { logger } from "./logger.js";

interface FcmPayload {
  token?: string;
  topic?: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

interface FcmResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

/**
 * Send a push notification via Firebase Admin SDK.
 * Falls back gracefully if not configured.
 */
export async function sendPushNotification(payload: FcmPayload): Promise<FcmResult> {
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
      notification: {
        title: payload.title,
        body: payload.body,
        ...(payload.imageUrl ? { imageUrl: payload.imageUrl } : {}),
      },
      data: payload.data ?? {},
      android: {
        priority: "high",
        notification: { channelId: "veedufix_high", priority: "max", defaultSound: true },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
      ...(payload.token ? { token: payload.token } : {}),
      ...(payload.topic && !payload.token ? { topic: payload.topic } : {}),
    };

    const messageId = await admin.messaging().send(message);
    logger.info({ messageId, title: payload.title }, "FCM push sent");
    return { success: true, messageId };
  } catch (error) {
    logger.warn({ error, title: payload.title }, "FCM push failed (non-fatal)");
    return { success: false, error: String(error) };
  }
}

/**
 * Send to multiple device tokens (multicast).
 */
export async function sendMulticastPush(
  payload: Omit<FcmPayload, "token" | "topic"> & { tokens: string[] }
): Promise<{ successCount: number; failureCount: number }> {
  if (!payload.tokens.length) return { successCount: 0, failureCount: 0 };
  try {
    const { default: admin } = await import("firebase-admin") as any;
    const result = await admin.messaging().sendEachForMulticast({
      tokens: payload.tokens,
      notification: { title: payload.title, body: payload.body },
      data: payload.data ?? {},
      android: { priority: "high", notification: { channelId: "veedufix_high" } },
    });
    logger.info({ successCount: result.successCount }, "FCM multicast sent");
    return { successCount: result.successCount, failureCount: result.failureCount };
  } catch (error) {
    logger.warn({ error }, "FCM multicast failed (non-fatal)");
    return { successCount: 0, failureCount: payload.tokens.length };
  }
}
