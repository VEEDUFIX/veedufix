import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../lib/prisma.js";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";

export const supportRouter = Router();

const createSupportTicketSchema = z.object({
  body: z.object({
    subject: z.string().min(3).max(120),
    message: z.string().min(10).max(5000),
    category: z.string().min(2).max(40).optional()
  })
});

const listSupportTicketsSchema = z.object({
  query: z
    .object({
      status: z.string().optional(),
      search: z.string().optional()
    })
    .optional()
});

const ticketParamsSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({}).optional(),
  params: z.object({
    ticketId: z.string().min(1)
  })
});

const updateSupportTicketStatusSchema = z.object({
  params: z.object({
    ticketId: z.string().min(1)
  }),
  body: z.object({
    status: z.enum(["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"])
  })
});

const updateSupportTicketAssignmentSchema = z.object({
  params: z.object({
    ticketId: z.string().min(1)
  }),
  body: z.object({
    assignedToUserId: z.string().min(1).nullable()
  })
});

const replySupportTicketSchema = z.object({
  params: z.object({
    ticketId: z.string().min(1)
  }),
  body: z.object({
    message: z.string().trim().min(2).max(5000),
    isInternal: z.boolean().optional()
  })
});

type SerializedReply = {
  id: string;
  message: string;
  isInternal: boolean;
  createdAt: string;
  author: {
    id: string;
    name: string;
    role: string;
  } | null;
};

function serializeReply(reply: {
  id: string;
  message: string;
  isInternal: boolean;
  createdAt: Date;
  author: { id: string; name: string; role: string } | null;
}): SerializedReply {
  return {
    id: reply.id,
    message: reply.message,
    isInternal: reply.isInternal,
    createdAt: reply.createdAt.toISOString(),
    author: reply.author
      ? {
          id: reply.author.id,
          name: reply.author.name,
          role: reply.author.role
        }
      : null
  };
}

function serializeTicket(ticket: any, includeInternalReplies = false) {
  return {
    id: ticket.id,
    subject: ticket.subject,
    message: ticket.message,
    status: ticket.status,
    createdAt: ticket.createdAt.toISOString(),
    updatedAt: ticket.updatedAt.toISOString(),
    replyCount: ticket._count?.replies ?? ticket.replies?.length ?? 0,
    user: ticket.user
      ? {
          id: ticket.user.id,
          name: ticket.user.name,
          phone: ticket.user.phone,
          role: ticket.user.role
        }
      : null,
    assignedTo: ticket.assignedTo
      ? {
          id: ticket.assignedTo.id,
          name: ticket.assignedTo.name,
          role: ticket.assignedTo.role
        }
      : null,
    replies: Array.isArray(ticket.replies)
      ? ticket.replies
          .filter((reply: any) => includeInternalReplies || !reply.isInternal)
          .map((reply: any) =>
          reply.author
            ? serializeReply({
                id: reply.id,
                message: reply.message,
                isInternal: Boolean(reply.isInternal),
                createdAt: reply.createdAt,
                author: reply.author
              })
            : {
                id: reply.id,
                message: reply.message,
                isInternal: Boolean(reply.isInternal),
                createdAt: new Date(reply.createdAt).toISOString(),
                author: null
              }
        )
      : []
  };
}

async function loadTicketWithThread(ticketId: string) {
  return prisma.supportTicket.findUnique({
    where: { id: ticketId },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          phone: true,
          role: true
        }
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          role: true
        }
      },
      replies: {
        orderBy: { createdAt: "asc" },
        include: {
          author: {
            select: {
              id: true,
              name: true,
              role: true
            }
          }
        }
      },
      _count: {
        select: { replies: true }
      }
    }
  });
}

async function requireTicketAccess(ticketId: string, userId: string, role: string) {
  const ticket = await prisma.supportTicket.findUnique({
    where: { id: ticketId },
    select: { id: true, userId: true, assignedToUserId: true }
  });

  if (!ticket) {
    return null;
  }

  if (role !== "ADMIN" && ticket.userId !== userId) {
    return null;
  }

  return ticket;
}

supportRouter.post(
  "/support/tickets",
  requireAuth,
  validate(createSupportTicketSchema),
  async (request: AuthenticatedRequest, response) => {
    const userId = request.auth!.userId;
    const { subject, message, category } = request.body as {
      subject: string;
      message: string;
      category?: string;
    };

    const ticket = await prisma.supportTicket.create({
      data: {
        userId,
        subject: category ? `[${category}] ${subject}` : subject,
        message,
        status: "OPEN"
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            phone: true,
            role: true
          }
        },
        assignedTo: {
          select: {
            id: true,
            name: true,
            role: true
          }
        },
        replies: true,
        _count: {
          select: { replies: true }
        }
      }
    });

    response.status(201).json({ ticket: serializeTicket(ticket) });
  }
);

supportRouter.get("/support/tickets/me", requireAuth, async (request: AuthenticatedRequest, response) => {
  const userId = request.auth!.userId;
  const tickets = await prisma.supportTicket.findMany({
    where: { userId },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          phone: true,
          role: true
        }
      },
      assignedTo: {
        select: {
          id: true,
          name: true,
          role: true
        }
      },
      replies: {
        orderBy: { createdAt: "asc" }
      },
      _count: {
        select: { replies: true }
      }
    },
    orderBy: { createdAt: "desc" },
    take: 20
  });

  response.json({ tickets: tickets.map((ticket) => serializeTicket(ticket)) });
});

supportRouter.get("/support/tickets/:ticketId", requireAuth, validate(ticketParamsSchema), async (request: AuthenticatedRequest, response) => {
  const ticketId = String(request.params.ticketId);
  const auth = request.auth!;
  const access = await requireTicketAccess(ticketId, auth.userId, auth.role);

  if (!access) {
    response.status(404).json({ message: "Ticket not found" });
    return;
  }

  const ticket = await loadTicketWithThread(ticketId);
  if (!ticket) {
    response.status(404).json({ message: "Ticket not found" });
    return;
  }

  response.json({ ticket: serializeTicket(ticket) });
});

supportRouter.get(
  "/admin/support/tickets/:ticketId",
  requireAuth,
  requireRole("ADMIN"),
  validate(ticketParamsSchema),
  async (request, response) => {
    const ticketId = String(request.params.ticketId);
    const ticket = await loadTicketWithThread(ticketId);

    if (!ticket) {
      response.status(404).json({ message: "Ticket not found" });
      return;
    }

    response.json({ ticket: serializeTicket(ticket, true) });
  }
);

supportRouter.get(
  "/admin/support/tickets",
  requireAuth,
  requireRole("ADMIN"),
  validate(listSupportTicketsSchema),
  async (request, response) => {
    const status = typeof request.query.status === "string" ? request.query.status : undefined;
    const search = typeof request.query.search === "string" ? request.query.search.trim() : "";

    const tickets = await prisma.supportTicket.findMany({
      where: {
        ...(status ? { status } : {}),
        ...(search
          ? {
              OR: [
                { id: { contains: search, mode: "insensitive" } },
                { subject: { contains: search, mode: "insensitive" } },
                { message: { contains: search, mode: "insensitive" } },
                { user: { name: { contains: search, mode: "insensitive" } } },
                { user: { phone: { contains: search, mode: "insensitive" } } },
                { assignedTo: { name: { contains: search, mode: "insensitive" } } }
              ]
            }
          : {})
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            phone: true,
            role: true
          }
        },
        assignedTo: {
          select: {
            id: true,
            name: true,
            role: true
          }
        },
        replies: true,
        _count: {
          select: { replies: true }
        }
      },
      orderBy: { createdAt: "desc" },
      take: 100
    });

    response.json({
      tickets: tickets.map((ticket) => serializeTicket(ticket, true))
    });
  }
);

supportRouter.patch(
  "/admin/support/tickets/:ticketId/status",
  requireAuth,
  requireRole("ADMIN"),
  validate(updateSupportTicketStatusSchema),
  async (request, response) => {
    const { ticketId } = request.params as { ticketId: string };
    const { status } = request.body as { status: "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED" };

    const ticket = await prisma.supportTicket.update({
      where: { id: ticketId },
      data: { status },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            phone: true,
            role: true
          }
        },
        assignedTo: {
          select: {
            id: true,
            name: true,
            role: true
          }
        },
        replies: true,
        _count: {
          select: { replies: true }
        }
      }
    });

    response.json({ ticket: serializeTicket(ticket, true) });
  }
);

supportRouter.patch(
  "/admin/support/tickets/:ticketId/assignment",
  requireAuth,
  requireRole("ADMIN"),
  validate(updateSupportTicketAssignmentSchema),
  async (request, response) => {
    const { ticketId } = request.params as { ticketId: string };
    const { assignedToUserId } = request.body as { assignedToUserId: string | null };

    const ticket = await prisma.supportTicket.update({
      where: { id: ticketId },
      data: { assignedToUserId },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            phone: true,
            role: true
          }
        },
        assignedTo: {
          select: {
            id: true,
            name: true,
            role: true
          }
        },
        replies: true,
        _count: {
          select: { replies: true }
        }
      }
    });

    response.json({ ticket: serializeTicket(ticket, true) });
  }
);

supportRouter.post(
  "/support/tickets/:ticketId/replies",
  requireAuth,
  validate(replySupportTicketSchema),
  async (request: AuthenticatedRequest, response) => {
    const ticketId = String(request.params.ticketId);
    const auth = request.auth!;
    const ticket = await requireTicketAccess(ticketId, auth.userId, auth.role);

    if (!ticket) {
      response.status(404).json({ message: "Ticket not found" });
      return;
    }

    const body = request.body as { message: string; isInternal?: boolean };
    if (body.isInternal && auth.role !== "ADMIN") {
      response.status(403).json({ message: "Only admins can add internal notes" });
      return;
    }

    const isInternal = auth.role === "ADMIN" ? Boolean(body.isInternal) : false;
    const reply = await prisma.supportTicketReply.create({
      data: {
        ticketId,
        authorUserId: auth.userId,
        message: body.message.trim(),
        isInternal
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            role: true
          }
        }
      }
    });

    const nextStatus =
      auth.role === "ADMIN"
        ? "IN_PROGRESS"
        : "OPEN";

    await prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: nextStatus,
        assignedToUserId: auth.role === "ADMIN" && !ticket.assignedToUserId ? auth.userId : ticket.assignedToUserId
      }
    });

    response.status(201).json({ reply: serializeReply(reply) });
  }
);

supportRouter.post(
  "/admin/support/tickets/:ticketId/replies",
  requireAuth,
  requireRole("ADMIN"),
  validate(replySupportTicketSchema),
  async (request: AuthenticatedRequest, response) => {
    const ticketId = String(request.params.ticketId);
    const body = request.body as { message: string; isInternal?: boolean };

    const reply = await prisma.supportTicketReply.create({
      data: {
        ticketId,
        authorUserId: request.auth!.userId,
        message: body.message.trim(),
        isInternal: Boolean(body.isInternal)
      },
      include: {
        author: {
          select: {
            id: true,
            name: true,
            role: true
          }
        }
      }
    });

    await prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status: "IN_PROGRESS",
        assignedToUserId: request.auth!.userId
      }
    });

    response.status(201).json({ reply: serializeReply(reply) });
  }
);
