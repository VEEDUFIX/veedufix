import { Router } from "express";
import { z } from "zod";
import { prisma } from "../../lib/prisma.js";
import { requireAuth, requireRole, type AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";

export const adminSearchRouter = Router();

const adminSearchSchema = z.object({
  body: z.object({}).optional(),
  query: z.object({
    q: z.string().trim().min(1).max(120)
  }),
  params: z.object({}).optional()
});

function routeForSearch(kind: "customer" | "worker" | "booking" | "ticket", value: string) {
  return switchRoute(kind, value);
}

function switchRoute(kind: "customer" | "worker" | "booking" | "ticket", value: string) {
  switch (kind) {
    case "customer":
      return `/customers?search=${encodeURIComponent(value)}`;
    case "worker":
      return `/workers/${value}`;
    case "booking":
      return `/admin-bookings?search=${encodeURIComponent(value)}`;
    case "ticket":
      return `/support-tickets?search=${encodeURIComponent(value)}`;
  }
}

adminSearchRouter.get(
  "/search",
  requireAuth,
  requireRole("ADMIN"),
  validate(adminSearchSchema),
  async (request: AuthenticatedRequest, response) => {
    const query = String(request.query.q ?? "").trim();
    if (!query) {
      response.json({
        customers: [],
        workers: [],
        bookings: [],
        tickets: []
      });
      return;
    }

    const [customers, workers, bookings, tickets] = await Promise.all([
      prisma.user.findMany({
        where: {
          role: "CUSTOMER",
          OR: [
            { name: { contains: query, mode: "insensitive" } },
            { email: { contains: query, mode: "insensitive" } },
            { phone: { contains: query, mode: "insensitive" } }
          ]
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          avatarUrl: true,
          createdAt: true
        },
        orderBy: { createdAt: "desc" },
        take: 8
      }),
      prisma.workerProfile.findMany({
        where: {
          OR: [
            { fullName: { contains: query, mode: "insensitive" } },
            { displayName: { contains: query, mode: "insensitive" } },
            { user: { name: { contains: query, mode: "insensitive" } } },
            { user: { email: { contains: query, mode: "insensitive" } } },
            { user: { phone: { contains: query, mode: "insensitive" } } },
            {
              skills: {
                some: {
                  category: {
                    name: { contains: query, mode: "insensitive" }
                  }
                }
              }
            }
          ]
        },
        include: {
          user: {
            select: {
              name: true,
              email: true,
              phone: true,
              avatarUrl: true
            }
          },
          skills: {
            include: {
              category: {
                select: {
                  name: true
                }
              }
            }
          }
        },
        orderBy: { createdAt: "desc" },
        take: 8
      }),
      prisma.booking.findMany({
        where: {
          OR: [
            { id: { contains: query, mode: "insensitive" } },
            { code: { contains: query, mode: "insensitive" } },
            { customer: { name: { contains: query, mode: "insensitive" } } },
            { customer: { phone: { contains: query, mode: "insensitive" } } },
            { worker: { fullName: { contains: query, mode: "insensitive" } } },
            {
              services: {
                some: {
                  OR: [
                    { service: { name: { contains: query, mode: "insensitive" } } },
                    { serviceSubcategory: { name: { contains: query, mode: "insensitive" } } }
                  ]
                }
              }
            }
          ]
        },
        include: {
          customer: {
            select: {
              name: true,
              phone: true
            }
          },
          worker: {
            select: {
              id: true,
              fullName: true,
              user: { select: { avatarUrl: true } }
            }
          },
          services: {
            include: {
              service: { select: { name: true } },
              serviceSubcategory: { select: { name: true } }
            }
          }
        },
        orderBy: { createdAt: "desc" },
        take: 8
      }),
      prisma.supportTicket.findMany({
        where: {
          OR: [
            { id: { contains: query, mode: "insensitive" } },
            { subject: { contains: query, mode: "insensitive" } },
            { message: { contains: query, mode: "insensitive" } },
            { user: { name: { contains: query, mode: "insensitive" } } },
            { user: { phone: { contains: query, mode: "insensitive" } } },
            { assignedTo: { name: { contains: query, mode: "insensitive" } } }
          ]
        },
        include: {
          user: {
            select: {
              name: true,
              phone: true,
              role: true
            }
          },
          assignedTo: {
            select: {
              name: true,
              role: true
            }
          }
        },
        orderBy: { createdAt: "desc" },
        take: 8
      })
    ]);

    response.json({
      customers: customers.map((customer) => ({
        id: customer.id,
        title: customer.name ?? customer.email ?? customer.phone ?? "Customer",
        subtitle: [customer.phone, customer.email].filter(Boolean).join(" · ") || "Customer",
        route: routeForSearch("customer", query),
        avatarUrl: customer.avatarUrl ?? null
      })),
      workers: workers.map((worker) => ({
        id: worker.id,
        title: worker.displayName ?? worker.fullName ?? worker.user.name ?? "Worker",
        subtitle: worker.skills.map((skill: any) => skill.category.name).slice(0, 3).join(" · ") || worker.user.phone || "Worker",
        route: routeForSearch("worker", worker.id),
        avatarUrl: worker.user.avatarUrl ?? null
      })),
      bookings: bookings.map((booking) => ({
        id: booking.id,
        title: booking.code,
        subtitle: [
          booking.customer.name ?? "Customer",
          booking.services[0]?.service?.name ?? booking.services[0]?.serviceSubcategory?.name ?? "Service",
          booking.status
        ].join(" · "),
        route: routeForSearch("booking", booking.id)
      })),
      tickets: tickets.map((ticket) => ({
        id: ticket.id,
        title: ticket.subject,
        subtitle: [
          ticket.user?.name ?? "User",
          ticket.assignedTo?.name ? `Assigned to ${ticket.assignedTo.name}` : "Unassigned",
          ticket.status
        ].join(" · "),
        route: routeForSearch("ticket", ticket.id)
      }))
    });
  }
);
