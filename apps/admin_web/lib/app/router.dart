import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/analytics_page.dart';
import '../features/catalog/presentation/pages/catalog_manager_page.dart';
import '../features/finance/presentation/pages/finance_home_page.dart';
import '../features/finance/presentation/pages/payouts_ledger_page.dart';
import '../features/finance/presentation/pages/refunds_ledger_page.dart';
import '../features/ops/presentation/pages/ops_alerts_page.dart';
import '../features/ops/presentation/pages/dispute_detail_page.dart';
import '../features/ops/presentation/pages/disputes_queue_page.dart';
import '../features/ops/presentation/pages/ops_live_jobs_page.dart';
import '../features/ops/presentation/pages/ops_overview_page.dart';
import '../features/worker_directory/presentation/pages/worker_directory_detail_page.dart';
import '../features/worker_directory/presentation/pages/worker_directory_page.dart';
import '../features/worker_directory/data/worker_directory_api.dart';
import '../features/worker_review/data/worker_review_api.dart';
import '../features/worker_review/presentation/pages/worker_review_detail_page.dart';
import '../features/worker_review/presentation/pages/worker_review_queue_page.dart';
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
      final homeRoute = homeRouteForMode(AppMode.admin);

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }

      if (location == '/login' || location == '/otp' || location == '/splash') {
        return homeRoute;
      }

      if (!_isAllowedLocation(AppMode.admin, location)) {
        return homeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(mode: AppMode.admin),
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
            path: '/admin',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsPage(),
          ),
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogManagerPage(),
          ),
          GoRoute(
            path: '/finance',
            builder: (context, state) => const FinanceHomePage(),
          ),
          GoRoute(
            path: '/finance/payouts',
            builder: (context, state) => const PayoutsLedgerPage(),
          ),
          GoRoute(
            path: '/finance/refunds',
            builder: (context, state) => const RefundsLedgerPage(),
          ),
          GoRoute(
            path: '/worker-review',
            builder: (context, state) => const WorkerReviewQueuePage(),
          ),
          GoRoute(
            path: '/workers',
            builder: (context, state) => const WorkerDirectoryPage(),
          ),
          GoRoute(
            path: '/ops/overview',
            builder: (context, state) => const OpsOverviewPage(),
          ),
          GoRoute(
            path: '/ops/live-jobs',
            builder: (context, state) => const OpsLiveJobsPage(),
          ),
          GoRoute(
            path: '/ops/alerts',
            builder: (context, state) => const OpsAlertsPage(),
          ),
          GoRoute(
            path: '/ops/disputes',
            builder: (context, state) => const DisputesQueuePage(),
          ),
          GoRoute(
            path: '/ops/disputes/:disputeId',
            builder: (context, state) {
              final disputeId = state.pathParameters['disputeId'] ?? '';
              return DisputeDetailPage(disputeId: disputeId);
            },
          ),
          GoRoute(
            path: '/worker-review/:profileId',
            builder: (context, state) {
              final profileId = state.pathParameters['profileId'] ?? '';
              final initialProfile = state.extra is WorkerReviewProfile
                  ? state.extra as WorkerReviewProfile
                  : null;
              return WorkerReviewDetailPage(
                profileId: profileId,
                initialProfile: initialProfile,
              );
            },
          ),
          GoRoute(
            path: '/workers/:profileId',
            builder: (context, state) {
              final profileId = state.pathParameters['profileId'] ?? '';
              final initialProfile = state.extra is WorkerDirectoryProfile
                  ? state.extra as WorkerDirectoryProfile
                  : null;
              return WorkerDirectoryDetailPage(
                profileId: profileId,
                initialProfile: initialProfile,
              );
            },
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

bool _isAllowedLocation(AppMode mode, String location) {
  final allowedRoutes = allowedRoutesForMode(mode);
  return allowedRoutes
      .any((route) => location == route || location.startsWith('$route/'));
}
