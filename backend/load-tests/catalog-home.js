import http from "k6/http";
import { check, sleep } from "k6";
import { baseUrl, getNumberEnv } from "./_shared.js";

export const options = {
  insecureSkipTLSVerify: false,
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<1500"]
  }
};

const cityId = (__ENV.CITY_ID || "").trim();
const locale = (__ENV.LOCALE || "en").trim();
const page = getNumberEnv("PAGE", 1);
const pageSize = getNumberEnv("PAGE_SIZE", 20);

export default function () {
  const url = new URL(`${baseUrl()}/api/catalog/home`);
  if (cityId) {
    url.searchParams.set("cityId", cityId);
  }
  url.searchParams.set("locale", locale);
  url.searchParams.set("page", String(page));
  url.searchParams.set("pageSize", String(pageSize));

  const response = http.get(url.toString(), {
    tags: { endpoint: "catalog-home" }
  });

  check(response, {
    "catalog home status is 200": (res) => res.status === 200,
    "catalog home returned json": (res) => (res.headers["Content-Type"] || "").includes("application/json")
  });

  sleep(1);
}

