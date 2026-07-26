import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/worker/presentation/pages/worker_dashboard_page.dart';
import '../features/worker/presentation/pages/jobs_page.dart';
import '../features/worker/presentation/pages/earnings_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/shell/presentation/pages/app_shell_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final session = authState.valueOrNull;

      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthRoute = location == '/login' || location == '/otp';
      final homeRoute = homeRouteForMode(AppMode.worker);

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }

      if (location == '/login' || location == '/otp' || location == '/splash') {
        return homeRoute;
      }

      if (!allowedRoutesForMode(AppMode.worker).contains(location)) {
        return homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(mode: AppMode.worker),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: '/worker',
            builder: (context, state) => const WorkerDashboardPage(),
          ),
          GoRoute(
            path: '/jobs',
            builder: (context, state) => const JobsPage(),
          ),
          GoRoute(
            path: '/earnings',
            builder: (context, state) => const EarningsPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
