import { Router } from "express";
import { chatHandler } from "./ai.controller.js";

export const aiRouter = Router();

aiRouter.post("/chat", chatHandler);
