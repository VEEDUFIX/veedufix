import express from "express";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../lib/auth-session.js", () => ({
  authenticateAccessToken: vi.fn(async (token: string) => ({
    sub: token === "admin-token" ? "admin-1" : "customer-1",
    role: token === "admin-token" ? "ADMIN" : "CUSTOMER",
    sessionId: "test-session"
  }))
}));

import { adminAiRouter } from "../modules/admin-ai/admin-ai.routes.js";

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use("/api/admin/ai", adminAiRouter);
  return app;
}

describe("Admin AI route protection", () => {
  const app = buildApp();

  beforeEach(() => vi.clearAllMocks());

  it("rejects requests without authentication", async () => {
    await request(app).get("/api/admin/ai/status").expect(401);
  });

  it("rejects a customer session from Admin AI endpoints", async () => {
    await request(app)
      .post("/api/admin/ai/search")
      .set("Authorization", "Bearer customer-token")
      .send({ prompt: "Show inactive services" })
      .expect(403);
  });

  it("exposes only a boolean provider configuration status to Admins", async () => {
    const response = await request(app)
      .get("/api/admin/ai/status")
      .set("Authorization", "Bearer admin-token")
      .expect(200);
    expect(response.body).toEqual(expect.objectContaining({
      configured: expect.any(Boolean),
      provider: "Google Gemini"
    }));
    expect(JSON.stringify(response.body)).not.toMatch(/AIza[0-9A-Za-z_-]{20,}|sk-[a-z0-9]{20,}/i);
  });
});
