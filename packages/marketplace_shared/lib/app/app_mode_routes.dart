import 'package:flutter/material.dart';

import 'app_mode.dart';

String appTitleForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => 'VeeduFix',
    AppMode.worker => 'VeeduFix Partner',
    AppMode.admin => 'VeeduFix Admin',
  };
}

String splashTitleForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => 'Trusted home services at your fingertips.',
    AppMode.worker => 'Jobs, earnings, and schedule control in one place.',
    AppMode.admin => 'Operate the marketplace from one secure panel.',
  };
}

String splashSubtitleForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer =>
      'Book verified professionals, track visits, and manage every service request.',
    AppMode.worker =>
      'Accept bookings, keep customers updated, and grow with every completed job.',
    AppMode.admin =>
      'Review demand, approvals, support, and revenue without leaving the dashboard.',
  };
}

IconData splashIconForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => Icons.home_repair_service_rounded,
    AppMode.worker => Icons.handyman_rounded,
    AppMode.admin => Icons.admin_panel_settings_rounded,
  };
}

String roleForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => 'CUSTOMER',
    AppMode.worker => 'WORKER',
    AppMode.admin => 'ADMIN',
  };
}

String homeRouteForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => '/app',
    AppMode.worker => '/worker',
    AppMode.admin => '/admin',
  };
}

String splashRouteForMode(AppMode mode) {
  return '/splash';
}

Set<String> allowedRoutesForMode(AppMode mode) {
  return switch (mode) {
    AppMode.customer => const {
        '/app',
        '/service',
        '/professional',
        '/checkout',
        '/tracking',
        '/chat',
        '/search',
        '/notifications',
        '/referral',
        '/support',
        '/bookings',
        '/arrival-otp',
        '/completion-otp',
        '/booking-rating',
        '/profile',
        '/addresses',
      },
    AppMode.worker => const {
        '/worker',
        '/jobs',
        '/job-execution',
        '/earnings',
        '/profile',
        '/onboarding',
        '/onboarding/status',
        '/availability',
      },
    AppMode.admin => const {
        '/admin',
        '/analytics',
        '/profile',
        '/catalog',
        '/finance',
        '/finance/payouts',
        '/finance/refunds',
        '/worker-review',
        '/workers',
        '/ops/overview',
        '/ops/live-jobs',
        '/ops/alerts',
        '/ops/disputes',
      },
  };
}
