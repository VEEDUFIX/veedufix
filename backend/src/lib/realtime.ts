import type { IncomingMessage, Server as HttpServer } from "http";
import type { Socket } from "net";
import { WebSocket, WebSocketServer } from "ws";
import { prisma } from "./prisma.js";
import { logger } from "./logger.js";
import { redis } from "./redis.js";
import { verifyAccessToken } from "./jwt.js";

type Role = "CUSTOMER" | "WORKER" | "ADMIN";

type RealtimeEnvelope<T extends Record<string, unknown>> = {
  type: string;
  channel: "tracking" | "notifications";
  timestamp: string;
  payload: T;
};

type TrackingPayload = {
  bookingId: string;
  status: string;
  message: string;
  actorRole?: Role;
  bookingCode?: string;
  paymentId?: string | null;
  photoType?: "before" | "after";
  photoUrl?: string;
  photoPublicId?: string;
  photoFolder?: string;
};

type NotificationPayload = {
  userId: string;
  title: string;
  body: string;
  type: string;
  data?: Record<string, unknown> | null;
};

type RealtimeAuth = {
  userId: string;
  role: Role;
  sessionId: string;
};

type SocketContext = {
  auth: RealtimeAuth;
  kind: "tracking" | "notifications";
  subscriber: ReturnType<typeof redis.duplicate>;
};

const PATH_TRACKING = "/api/tracking/ws";
const PATH_NOTIFICATIONS = "/api/notifications/ws";

let websocketServer: WebSocketServer | null = null;
let attachedServer: HttpServer | null = null;

function channelForTracking(bookingId: string): string {
  return `realtime:tracking:booking:${bookingId}`;
}

function channelForNotification(userId: string): string {
  return `realtime:notifications:user:${userId}`;
}

function parseToken(request: IncomingMessage): string | null {
  const url = new URL(request.url ?? "", "http://localhost");
  return url.searchParams.get("token");
}

function parseBookingId(request: IncomingMessage): string | null {
  const url = new URL(request.url ?? "", "http://localhost");
  return url.searchParams.get("bookingId");
}

function sendJson(socket: WebSocket, envelope: RealtimeEnvelope<Record<string, unknown>>) {
  if (socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(envelope));
  }
}

async function emitTrackingEvent(payload: TrackingPayload): Promise<void> {
  const envelope: RealtimeEnvelope<TrackingPayload> = {
    type: "tracking.event",
    channel: "tracking",
    timestamp: new Date().toISOString(),
    payload
  };
  await redis.publish(channelForTracking(payload.bookingId), JSON.stringify(envelope));
}

async function emitNotificationEvent(payload: NotificationPayload): Promise<void> {
  const envelope: RealtimeEnvelope<NotificationPayload> = {
    type: "notification.event",
    channel: "notifications",
    timestamp: new Date().toISOString(),
    payload
  };
  await redis.publish(channelForNotification(payload.userId), JSON.stringify(envelope));
}

async function authorizeConnection(
  kind: "tracking" | "notifications",
  request: IncomingMessage
): Promise<SocketContext> {
  const token = parseToken(request);
  if (!token) {
    throw new Error("Missing access token");
  }

  const payload = verifyAccessToken(token);
  const auth: RealtimeAuth = {
    userId: payload.sub,
    role: payload.role,
    sessionId: payload.sessionId
  };
  const subscriber = redis.duplicate();

  if (kind === "notifications") {
    return { auth, kind, subscriber };
  }

  const bookingId = parseBookingId(request);
  if (!bookingId) {
    throw new Error("Missing bookingId");
  }

  const booking = await prisma.booking.findUnique({
    where: { id: bookingId },
    include: {
      worker: {
        include: {
          user: true
        }
      }
    }
  });

  if (!booking) {
    throw new Error("Booking not found");
  }

  const isCustomer = booking.customerId === auth.userId;
  const isWorker = booking.worker?.userId === auth.userId;
  const isAdmin = auth.role === "ADMIN";

  if (!isCustomer && !isWorker && !isAdmin) {
    throw new Error("Access denied");
  }

  return { auth, kind, subscriber };
}

async function bindTrackingSocket(socket: WebSocket, request: IncomingMessage) {
  const context = await authorizeConnection("tracking", request);
  const bookingId = parseBookingId(request);
  const channel = channelForTracking(bookingId!);
  await context.subscriber.subscribe(channel);

  context.subscriber.on("message", (_channel, message) => {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(message);
    }
  });

  socket.send(
    JSON.stringify({
      type: "connected",
      channel: "tracking",
      timestamp: new Date().toISOString(),
      payload: {
        bookingId,
        userId: context.auth.userId,
        role: context.auth.role
      }
    })
  );

  socket.on("message", (raw) => {
    try {
      const text = raw.toString("utf8");
      const data = JSON.parse(text) as { type?: string };
      if (data.type === "ping") {
        sendJson(socket, {
          type: "pong",
          channel: "tracking",
          timestamp: new Date().toISOString(),
          payload: {}
        });
      }
    } catch {
      // Ignore malformed client messages.
    }
  });

  socket.on("close", async () => {
    try {
      await context.subscriber.unsubscribe(channel);
      await context.subscriber.quit();
    } catch {
      // Ignore disconnect cleanup issues.
    }
  });
}

async function bindNotificationSocket(socket: WebSocket, request: IncomingMessage) {
  const context = await authorizeConnection("notifications", request);
  const channel = channelForNotification(context.auth.userId);
  await context.subscriber.subscribe(channel);

  context.subscriber.on("message", (_channel, message) => {
    if (socket.readyState === WebSocket.OPEN) {
      socket.send(message);
    }
  });

  socket.send(
    JSON.stringify({
      type: "connected",
      channel: "notifications",
      timestamp: new Date().toISOString(),
      payload: {
        userId: context.auth.userId,
        role: context.auth.role
      }
    })
  );

  socket.on("message", (raw) => {
    try {
      const text = raw.toString("utf8");
      const data = JSON.parse(text) as { type?: string };
      if (data.type === "ping") {
        sendJson(socket, {
          type: "pong",
          channel: "notifications",
          timestamp: new Date().toISOString(),
          payload: {}
        });
      }
    } catch {
      // Ignore malformed client messages.
    }
  });

  socket.on("close", async () => {
    try {
      await context.subscriber.unsubscribe(channel);
      await context.subscriber.quit();
    } catch {
      // Ignore disconnect cleanup issues.
    }
  });
}

function onUpgrade(request: IncomingMessage, socket: Socket, head: Buffer) {
  const url = new URL(request.url ?? "", "http://localhost");
  if (url.pathname === PATH_TRACKING) {
    websocketServer?.handleUpgrade(request, socket, head, (ws) => {
      void bindTrackingSocket(ws, request).catch((error) => {
        logger.warn({ error }, "Tracking websocket rejected");
        ws.close(1008, "Unauthorized");
      });
    });
    return;
  }

  if (url.pathname === PATH_NOTIFICATIONS) {
    websocketServer?.handleUpgrade(request, socket, head, (ws) => {
      void bindNotificationSocket(ws, request).catch((error) => {
        logger.warn({ error }, "Notification websocket rejected");
        ws.close(1008, "Unauthorized");
      });
    });
    return;
  }

  socket.destroy();
}

export function attachRealtimeGateway(server: HttpServer): void {
  if (websocketServer || attachedServer === server) {
    return;
  }

  websocketServer = new WebSocketServer({ noServer: true });
  attachedServer = server;
  server.on("upgrade", onUpgrade);
  logger.info("Realtime websocket gateway attached");
}

export async function publishTrackingEvent(payload: TrackingPayload): Promise<void> {
  await emitTrackingEvent(payload);
}

export async function publishNotificationEvent(payload: NotificationPayload): Promise<void> {
  await emitNotificationEvent(payload);
}
