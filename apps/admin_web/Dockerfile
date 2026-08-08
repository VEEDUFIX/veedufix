# Stage 1: Build
FROM cirrusci/flutter:stable AS builder

WORKDIR /app

# Copy the shared package
COPY packages/marketplace_shared ./packages/marketplace_shared

# Copy the admin web app
COPY apps/admin_web ./apps/admin_web

# Get dependencies for shared package
WORKDIR /app/packages/marketplace_shared
RUN flutter pub get

# Build the admin web app
WORKDIR /app/apps/admin_web
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve
FROM nginx:alpine

# Copy the built web app from the builder stage
COPY --from=builder /app/apps/admin_web/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
