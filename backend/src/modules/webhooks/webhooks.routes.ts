import { Router } from "express";
import { razorpayWebhookHandler, razorpayxWebhookHandler } from "./webhooks.controller.js";

export const webhooksRouter = Router();

webhooksRouter.post("/razorpay", razorpayWebhookHandler);
webhooksRouter.post("/razorpayx", razorpayxWebhookHandler);
