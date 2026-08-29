# Stage 1: Build
FROM cirrusci/flutter:stable AS builder

WORKDIR /app

# Copy the shared package
COPY packages/marketplace_shared ./packages/marketplace_shared

# Copy the admin web app
COPY apps/admin_web ./apps/admin_web

ARG API_BASE_URL
ARG GOOGLE_SERVER_CLIENT_ID
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_API_KEY
ARG FIREBASE_APP_ID
ARG FIREBASE_MESSAGING_SENDER_ID
ARG FIREBASE_STORAGE_BUCKET
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_DATABASE_URL
ARG FIREBASE_MEASUREMENT_ID

# Get dependencies for shared package
WORKDIR /app/packages/marketplace_shared
RUN flutter pub get

# Build the admin web app
WORKDIR /app/apps/admin_web
RUN flutter pub get
RUN flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-http://localhost:4000/api}" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID:-}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID:-}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}" \
  --dart-define=FIREBASE_STORAGE_BUCKET="${FIREBASE_STORAGE_BUCKET:-}" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_DATABASE_URL="${FIREBASE_DATABASE_URL:-}" \
  --dart-define=FIREBASE_MEASUREMENT_ID="${FIREBASE_MEASUREMENT_ID:-}" \
  --dart-define=PRODUCTION=true

# Stage 2: Serve
FROM nginx:alpine

# Copy the built web app from the builder stage
COPY --from=builder /app/apps/admin_web/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
