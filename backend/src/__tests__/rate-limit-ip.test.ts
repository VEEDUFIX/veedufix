import { describe, expect, it } from "vitest";
import { ipKeyGenerator } from "express-rate-limit";
import type { Request } from "express";
import { clientIpKey } from "../lib/rate-limit.js";

describe("clientIpKey", () => {
  it("uses the visitor address from the forwarded IP chain", () => {
    const request = {
      headers: { "x-forwarded-for": "203.0.113.42, 104.23.160.231, 10.0.0.2" },
      ip: "::1"
    } as unknown as Request;

    expect(clientIpKey(request)).toBe(ipKeyGenerator("203.0.113.42"));
  });

  it("falls back to Express IP when the forwarded value is invalid", () => {
    const request = {
      headers: { "x-forwarded-for": "not-an-ip, 10.0.0.2" },
      ip: "192.0.2.15"
    } as unknown as Request;

    expect(clientIpKey(request)).toBe(ipKeyGenerator("192.0.2.15"));
  });
});
