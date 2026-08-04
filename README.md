# Local Services Marketplace

Production-grade Flutter and Node.js foundation for a local service marketplace inspired by Urban Company, designed for a single city first and structured for multi-city expansion.

## Structure

- `apps/customer_app` - Flutter VeeduFix customer app
- `apps/worker_app` - Flutter VeeduFix Partner app
- `apps/admin_web` - Flutter web admin panel
- `packages/marketplace_shared` - Shared Flutter core, auth, theme, and utilities
- `backend` - Express, Prisma, PostgreSQL, Redis, and auth foundation

## Foundation covered in this pass

- Clean architecture and feature-first layout
- Role-aware navigation for customer, worker, and admin
- Authentication contracts for mobile OTP, email, and Google sign-in
- PostgreSQL schema for users, workers, cities, services, bookings, payments, and reviews
- Backend security middleware, validation, and shared infrastructure

## Run

From the repo root, run:

```powershell
.\bootstrap.ps1
```

This hydrates all Flutter packages in the correct order.

### Backend

```bash
cd backend
npm install
npm run dev
```

### VeeduFix

```bash
cd apps/customer_app
flutter pub get
flutter run
```

### VeeduFix Partner

```bash
cd apps/worker_app
flutter pub get
flutter run
```

### Admin Web Panel

```bash
cd apps/admin_web
flutter pub get
flutter run -d chrome
```

## Notes

This repository is scaffolded to be expanded feature-by-feature. The current codebase establishes the production foundation requested in the brief and is ready for authentication and booking feature work next.

## Deployment

- Admin web surface: Vercel static deployment from `apps/admin_web`
- Backend API: Render web service from `backend`
- Primary database: Neon PostgreSQL

### Local backend `.env`

Use the backend environment file as the source of truth:

- `backend/.env.example`

Minimum local setup:

```dotenv
NODE_ENV=development
PORT=4000
DATABASE_URL=postgresql://USER:PASSWORD@HOST-Pooler.neon.tech/veedufix?sslmode=require
DIRECT_URL=postgresql://USER:PASSWORD@HOST.neon.tech/veedufix?sslmode=require
REDIS_URL=redis://localhost:6379
JWT_ACCESS_SECRET=replace-with-a-long-random-secret
JWT_REFRESH_SECRET=replace-with-a-long-random-secret
APP_CORS_ORIGIN=http://localhost:3000,http://localhost:3001,http://localhost:5173
GOOGLE_SERVER_CLIENT_ID=your-google-oauth-web-client-id.apps.googleusercontent.com
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
```

Neon notes:

- `DATABASE_URL` should use the pooled Neon connection string for app traffic.
- `DIRECT_URL` should use the direct Neon connection string for Prisma migrations and admin operations.
- Keep `sslmode=require` on both URLs.

### Render backend service

Set these variables in Render for `backend`:

- `NODE_ENV=production`
- `PORT=10000`
- `DATABASE_URL=<Neon pooled URL>`
- `DIRECT_URL=<Neon direct URL>`
- `REDIS_URL=<Render Redis or other Redis URL>`
- `JWT_ACCESS_SECRET=<strong secret>`
- `JWT_REFRESH_SECRET=<strong secret>`
- `APP_CORS_ORIGIN=https://veedufix.vercel.app,https://veedufix-partner.vercel.app`
- `GOOGLE_SERVER_CLIENT_ID=<Google OAuth web client ID>`
- `RAZORPAY_KEY_ID=<Razorpay key id>`
- `RAZORPAY_KEY_SECRET=<Razorpay key secret>`
- `RAZORPAY_WEBHOOK_URL=https://veedufix-backend.onrender.com/api/webhooks/razorpay`
- `RAZORPAY_WEBHOOK_SECRET=<Razorpay webhook secret>`
- `CLOUDINARY_CLOUD_NAME=<Cloudinary cloud name>`
- `CLOUDINARY_API_KEY=<Cloudinary api key>`
- `CLOUDINARY_API_SECRET=<Cloudinary api secret>`

Optional Firebase values for future backend integrations:

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Cloudinary is the preferred image store for:

- customer profile photos
- worker portfolio and verification images
- service and category imagery

Backend upload endpoints:

- `POST /api/media/avatar`
- `POST /api/media/workers/portfolio`
- `POST /api/media/workers/document`

Payment webhooks:

- `POST /api/webhooks/razorpay`
- `POST /api/webhooks/razorpayx`

Realtime websocket endpoints:

- `ws://<backend-host>/api/tracking/ws?token=<access_token>&bookingId=<booking_id>`
- `ws://<backend-host>/api/notifications/ws?token=<access_token>`

Tracking streams are booking-scoped and notifications are user-scoped. Both use the existing JWT access token returned by login.

### Vercel admin web app

The admin web build reads build-time defines from environment variables in `apps/admin_web/scripts/build_web.sh`.

Set these in the Vercel project:

- `API_BASE_URL=https://<your-render-service>.onrender.com/api`
- `GOOGLE_SERVER_CLIENT_ID=<Google OAuth web client ID>`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_DATABASE_URL`
- `FIREBASE_MEASUREMENT_ID`

The Vercel build command already forwards those values into `flutter build web` as `--dart-define`s.

### Flutter apps locally

Customer and worker apps default to `http://localhost:4000/api`, but you can override it:

```powershell
cd apps/customer_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api --dart-define=GOOGLE_MAPS_API_KEY=your_google_maps_key
```

```powershell
cd apps/worker_app
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000/api --dart-define=GOOGLE_MAPS_API_KEY=your_google_maps_key
```

If Firebase is enabled for a Flutter target, pass the same build-time values through `--dart-define` or your IDE run configuration.
For Google Maps on the customer app, enable `Maps SDK for Android`, `Maps SDK for iOS`, `Places API`, and `Geocoding API` in the same Google Cloud project, then pass the API key as `GOOGLE_MAPS_API_KEY`.
