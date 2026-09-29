import { z } from "zod";

const messageSchema = z.object({
  role: z.enum(["user", "model"]),
  parts: z.array(z.object({ text: z.string().trim().min(1).max(1600) }).strict()).min(1).max(1)
}).strict();

export const chatSchema = z.object({
  body: z.object({
    message: z.string().trim().min(1).max(1600),
    history: z.array(messageSchema).max(10).default([])
  }).strict()
});

export type ChatMessage = z.infer<typeof messageSchema>;
