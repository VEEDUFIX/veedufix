import { UserRole } from "@prisma/client";
import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";

export async function getOrCreateChatRoom(bookingId: string, userId: string, role: UserRole) {
  const booking = await db.booking.findUnique({
    where: { id: bookingId }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  if (role === "CUSTOMER" && booking.customerId !== userId) {
    throw AppError.forbidden("Unauthorized");
  }

  if (role === "WORKER" && booking.workerId !== userId) {
    throw AppError.forbidden("Unauthorized");
  }

  let chatRoom = await db.chatRoom.findUnique({
    where: { bookingId },
    include: {
      messages: {
        orderBy: { createdAt: "asc" }
      }
    }
  });

  if (!chatRoom) {
    chatRoom = await db.chatRoom.create({
      data: {
        bookingId
      },
      include: {
        messages: {
          orderBy: { createdAt: "asc" }
        }
      }
    });
  }

  return chatRoom;
}

export async function saveMessage(
  bookingId: string,
  senderId: string,
  senderRole: UserRole,
  content: string,
  attachments?: Array<{ url: string; name?: string; mimeType?: string; size?: number; kind: "image" | "file" }>
) {
  const chatRoom = await db.chatRoom.findUnique({
    where: { bookingId }
  });

  if (!chatRoom) {
    throw AppError.notFound("Chat room not found");
  }

  const message = await db.message.create({
    data: {
      chatRoomId: chatRoom.id,
      senderId,
      senderRole,
      content,
      attachments: attachments && attachments.length > 0 ? attachments : undefined
    }
  });

  return message;
}

export async function markMessagesAsRead(bookingId: string, userId: string) {
  const chatRoom = await db.chatRoom.findUnique({
    where: { bookingId }
  });

  if (!chatRoom) {
    throw AppError.notFound("Chat room not found");
  }

  await db.message.updateMany({
    where: {
      chatRoomId: chatRoom.id,
      senderId: { not: userId },
      isRead: false
    },
    data: {
      isRead: true
    }
  });
}
