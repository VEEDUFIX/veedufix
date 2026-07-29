import { Request, Response } from "express";
import { aiService } from "./ai.service.js";

export async function chatHandler(request: Request, response: Response): Promise<void> {
  try {
    const { message, history } = request.body;
    
    if (!message) {
      response.status(400).json({ error: "Message is required" });
      return;
    }

    const reply = await aiService.chat(message, history || []);
    response.status(200).json({ reply });
  } catch (error) {
    console.error("Chat Handler Error:", error);
    response.status(500).json({ error: "Failed to process chat" });
  }
}
