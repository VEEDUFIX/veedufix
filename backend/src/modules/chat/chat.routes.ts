import { Router } from "express";
import { requireAuth } from "../../middleware/auth.js";
import { validate } from "../../middleware/validate.js";
import { getChatRoomParamsSchema, markAsReadSchema, sendMessageSchema } from "./chat.schemas.js";
import { getChatRoomHandler, markAsReadHandler, sendMessageHandler } from "./chat.controller.js";

export const chatRouter = Router();

chatRouter.use(requireAuth);

chatRouter.get("/:bookingId", validate(getChatRoomParamsSchema), getChatRoomHandler);
chatRouter.post("/:bookingId/messages", validate(sendMessageSchema), sendMessageHandler);
chatRouter.post("/:bookingId/read", validate(markAsReadSchema), markAsReadHandler);
