import { fail } from "k6";

export function baseUrl() {
  const value = (__ENV.BASE_URL || "").trim().replace(/\/+$/, "");
  if (!value) {
    fail("Set BASE_URL to a staging or test backend URL");
  }
  return value;
}

export function adminHeaders() {
  const token = (__ENV.ADMIN_TOKEN || "").trim();
  if (!token) {
    fail("Set ADMIN_TOKEN to a valid admin bearer token for protected endpoints");
  }

  return {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json"
  };
}

export function jsonHeaders() {
  return {
    "Content-Type": "application/json"
  };
}

export function getNumberEnv(name, fallback) {
  const raw = __ENV[name];
  if (raw === undefined || raw === null || raw === "") {
    return fallback;
  }

  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    fail(`Environment variable ${name} must be a number`);
  }

  return parsed;
}

