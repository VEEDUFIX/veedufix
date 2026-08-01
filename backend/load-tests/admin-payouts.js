import http from "k6/http";
import { check, sleep } from "k6";
import { adminHeaders, baseUrl, getNumberEnv } from "./_shared.js";

export const options = {
  insecureSkipTLSVerify: false,
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1500"]
  }
};

const status = (__ENV.PAYOUT_STATUS || "").trim();
const workerId = (__ENV.WORKER_ID || "").trim();
const page = getNumberEnv("PAGE", 1);
const limit = getNumberEnv("LIMIT", 50);

export default function () {
  const url = new URL(`${baseUrl()}/api/admin/payouts`);
  url.searchParams.set("page", String(page));
  url.searchParams.set("limit", String(limit));
  if (status) {
    url.searchParams.set("status", status);
  }
  if (workerId) {
    url.searchParams.set("workerId", workerId);
  }

  const response = http.get(url.toString(), {
    headers: adminHeaders(),
    tags: { endpoint: "admin-payouts" }
  });

  check(response, {
    "admin payouts status is 200": (res) => res.status === 200,
    "admin payouts returned json": (res) => (res.headers["Content-Type"] || "").includes("application/json")
  });

  sleep(getNumberEnv("SLEEP_SECONDS", 1));
}

