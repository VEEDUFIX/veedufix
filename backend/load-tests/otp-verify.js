import http from "k6/http";
import { check, sleep } from "k6";
import { baseUrl, getNumberEnv, jsonHeaders } from "./_shared.js";

export const options = {
  insecureSkipTLSVerify: false,
  thresholds: {
    http_req_failed: ["rate<0.05"],
    http_req_duration: ["p(95)<1200"]
  }
};

const identifier = (__ENV.OTP_IDENTIFIER || "").trim();
if (!identifier) {
  throw new Error("Set OTP_IDENTIFIER to a fixed phone number or email for rate-limit testing");
}

const channel = (__ENV.OTP_CHANNEL || "PHONE").trim().toUpperCase();
const otp = (__ENV.OTP_VALUE || "000000").trim();
const name = (__ENV.OTP_NAME || "Load Test User").trim();
const referralCode = (__ENV.REFERRAL_CODE || "").trim();

export default function () {
  const payload = {
    channel,
    identifier,
    otp,
    name
  };

  if (referralCode) {
    payload.referralCode = referralCode;
  }

  const response = http.post(`${baseUrl()}/api/auth/otp/verify`, JSON.stringify(payload), {
    headers: jsonHeaders(),
    tags: { endpoint: "otp-verify" }
  });

  check(response, {
    "otp verify returned expected http response": (res) => [200, 400, 401, 403, 429].includes(res.status)
  });

  sleep(getNumberEnv("SLEEP_SECONDS", 0.2));
}

