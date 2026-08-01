import http from "k6/http";
import { check, sleep } from "k6";
import { adminHeaders, baseUrl, getNumberEnv } from "./_shared.js";

export const options = {
  insecureSkipTLSVerify: false,
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<2000"]
  }
};

const bookingId = (__ENV.BOOKING_ID || "").trim();
if (!bookingId) {
  throw new Error("Set BOOKING_ID to a real booking id from the staging environment");
}

export default function () {
  const url = `${baseUrl()}/api/bookings/${encodeURIComponent(bookingId)}/dispatch`;
  const response = http.post(url, "{}", {
    headers: adminHeaders(),
    tags: { endpoint: "booking-dispatch" }
  });

  check(response, {
    "dispatch status is 200/201/202/204": (res) => [200, 201, 202, 204].includes(res.status),
    "dispatch responded": (res) => res.timings.duration >= 0
  });

  sleep(getNumberEnv("SLEEP_SECONDS", 1));
}

