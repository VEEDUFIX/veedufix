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
