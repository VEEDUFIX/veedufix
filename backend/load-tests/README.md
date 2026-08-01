# K6 load tests

These scripts are intended for a staging or test backend only.

## Prerequisites

- Install `k6` locally, or run the tests in a CI agent that already has it.
- Set `BASE_URL` to the staging backend URL, not production.
- For protected routes, set `ADMIN_TOKEN` to a valid admin bearer token from staging.
- For booking dispatch, set `BOOKING_ID` to a real booking id in staging.
- For OTP rate limiting, set `OTP_IDENTIFIER` to a fixed phone number or email used only for load testing.

## Suggested sweep

Run each test at 10, 50, 100, and 500 VUs, keeping the duration short at first:

```powershell
Set-Location C:\Users\AAA\Documents\veedufix\backend
$env:BASE_URL = "https://staging.example.com"
k6 run -u 10 -d 2m load-tests/catalog-home.js
k6 run -u 50 -d 2m load-tests/catalog-home.js
k6 run -u 100 -d 2m load-tests/catalog-home.js
k6 run -u 500 -d 2m load-tests/catalog-home.js
```

Repeat the same ramp for:

- `load-tests/booking-dispatch.js`
- `load-tests/otp-verify.js`
- `load-tests/admin-payouts.js`

## What to watch

- Render CPU and memory on the single backend instance.
- Neon connection count and any pool saturation or queueing.
- Redis latency and rate-limit key churn during the OTP test.
- p95 latency and the first point where HTTP 429, 5xx, or timeouts begin.
