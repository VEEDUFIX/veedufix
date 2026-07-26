import { Router } from "express";
import { requireAuth, type AuthenticatedRequest } from "../../middleware/auth.js";
import { prisma } from "../../lib/prisma.js";

export const usersRouter = Router();

usersRouter.get("/me", requireAuth, async (request: AuthenticatedRequest, response) => {
  const user = await prisma.user.findUnique({
    where: { id: request.auth!.userId },
    include: {
      city: true,
      workerProfile: true,
      addresses: true
    }
  });

  if (!user) {
    response.status(404).json({ message: "User not found" });
    return;
  }

  response.status(200).json({ user });
});
