import { Router } from "express";
import { z } from "zod";
import { requireAuth, type AuthenticatedRequest } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { getTokensForUser, revokeDeviceToken, upsertDeviceToken } from "./device-token.service.js";

export const deviceTokenRouter = Router();

const tokenSchema = z.object({
  body: z.object({
    token: z.string().min(10),
    platform: z.string().min(2).max(20).optional(),
    deviceId: z.string().min(1).max(200).optional()
  })
});

deviceTokenRouter.use(requireAuth);

deviceTokenRouter.get("/me", async (request: AuthenticatedRequest, response) => {
  const tokens = await getTokensForUser(request.auth!.userId);
  response.status(200).json({ tokens });
});

deviceTokenRouter.post("/", validate(tokenSchema), async (request: AuthenticatedRequest, response) => {
  const { token, platform, deviceId } = request.body;

  await upsertDeviceToken(request.auth!.userId, { token, platform, deviceId });

  response.status(200).json({ success: true });
});

deviceTokenRouter.delete("/", validate(tokenSchema), async (request: AuthenticatedRequest, response) => {
  const { token } = request.body;
  const removed = await revokeDeviceToken(request.auth!.userId, token);

  response.status(200).json({ success: true, removed });
});
