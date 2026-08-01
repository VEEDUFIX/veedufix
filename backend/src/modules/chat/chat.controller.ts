import { Response } from "express";
import { AuthenticatedRequest } from "../../middleware/auth.js";
import { getOrCreateChatRoom, markMessagesAsRead, saveMessage } from "./chat.service.js";
import { logger } from "../../lib/logger.js";
import { UserRole } from "@prisma/client";

export async function getChatRoomHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const bookingId = request.params.bookingId as string;
    const userId = request.auth!.userId;
    const role = request.auth!.role as UserRole;

    const chatRoom = await getOrCreateChatRoom(bookingId, userId, role);
    const unreadCount = chatRoom.messages.filter((message) => !message.isRead && message.senderId !== userId).length;
    response.json({ chatRoom, unreadCount });
  } catch (error) {
    logger.error({ error, bookingId: request.params.bookingId }, "Failed to get chat room");
    if (error instanceof Error && error.message === "Unauthorized") {
      response.status(403).json({ message: "Not authorized to access this chat room" });
    } else {
      response.status(500).json({ message: "Internal server error" });
    }
  }
}

export async function sendMessageHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const bookingId = request.params.bookingId as string;
    const { content, attachments } = request.body;
    const userId = request.auth!.userId;
    const role = request.auth!.role as UserRole;

    await getOrCreateChatRoom(bookingId, userId, role);
    const message = await saveMessage(bookingId, userId, role, content, attachments);

    response.json({ message });
  } catch (error) {
    logger.error({ error, bookingId: request.params.bookingId }, "Failed to send message");
    response.status(500).json({ message: "Internal server error" });
  }
}

export async function markAsReadHandler(request: AuthenticatedRequest, response: Response) {
  try {
    const bookingId = request.params.bookingId as string;
    const userId = request.auth!.userId;

    await markMessagesAsRead(bookingId, userId);

    response.json({ success: true });
  } catch (error) {
    logger.error({ error, bookingId: request.params.bookingId }, "Failed to mark messages as read");
    response.status(500).json({ message: "Internal server error" });
  }
}
