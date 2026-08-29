import { UserRole } from "@prisma/client";
import { prisma as db } from "../../lib/prisma.js";
import { AppError } from "../../lib/app-error.js";

async function assertChatAccess(bookingId: string, userId: string, role: UserRole) {
  const booking = await db.booking.findUnique({
    where: { id: bookingId },
    select: {
      id: true,
      customerId: true,
      worker: {
        select: {
          userId: true
        }
      }
    }
  });

  if (!booking) {
    throw AppError.notFound("Booking not found");
  }

  const isCustomer = booking.customerId === userId;
  const isWorker = booking.worker?.userId === userId;
  const isAdmin = role === "ADMIN";

  if (!isCustomer && !isWorker && !isAdmin) {
    throw AppError.forbidden("Unauthorized");
  }

  return booking;
}

export async function getOrCreateChatRoom(bookingId: string, userId: string, role: UserRole) {
  await assertChatAccess(bookingId, userId, role);

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
  await assertChatAccess(bookingId, senderId, senderRole);

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

export async function markMessagesAsRead(bookingId: string, userId: string, role: UserRole) {
  await assertChatAccess(bookingId, userId, role);

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
