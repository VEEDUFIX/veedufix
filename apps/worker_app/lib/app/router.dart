import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../features/onboarding/presentation/pages/onboarding_flow_page.dart';
import '../features/onboarding/presentation/pages/onboarding_status_page.dart';
import '../features/onboarding/presentation/providers/onboarding_provider.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/worker/presentation/pages/job_execution_page.dart';
import '../features/worker/presentation/pages/worker_dashboard_page.dart';
import '../features/worker/presentation/pages/jobs_page.dart';
import '../features/worker/presentation/pages/earnings_page.dart';
import '../features/profile/presentation/pages/worker_availability_page.dart';
import '../features/worker/presentation/providers/job_execution_provider.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/shell/presentation/pages/app_shell_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) async {
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

      final onboardingProfile = await ref.read(workerOnboardingStatusProvider.future);
      final onboardingStatus = onboardingProfile?.onboardingStatus ?? 'pending_documents';
      final isEditMode = state.uri.queryParameters['mode'] == 'edit';

      if (onboardingStatus == 'approved') {
        if (!allowedRoutesForMode(AppMode.worker).contains(location)) {
          return homeRoute;
        }
        return null;
      }

      if (onboardingStatus == 'under_review' || onboardingStatus == 'suspended') {
        return location == '/onboarding/status' ? null : '/onboarding/status';
      }

      if (onboardingStatus == 'rejected') {
        if (location == '/onboarding' && isEditMode) {
          return null;
        }
        return location == '/onboarding/status' ? null : '/onboarding/status';
      }

      if (location == '/onboarding' || location == '/onboarding/status') {
        return null;
      }

      return '/onboarding';
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
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingFlowPage(),
      ),
      GoRoute(
        path: '/onboarding/status',
        builder: (context, state) => const OnboardingStatusPage(),
      ),
      GoRoute(
        path: '/availability',
        builder: (context, state) => const WorkerAvailabilityPage(),
      ),
      GoRoute(
        path: '/job-execution',
        builder: (context, state) {
          final booking = state.extra;
          if (booking is JobExecutionBooking) {
            return JobExecutionPage(booking: booking);
          }
          return const _MissingJobExecutionPage();
        },
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

class _MissingJobExecutionPage extends StatelessWidget {
  const _MissingJobExecutionPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: PremiumEmptyState(
          icon: Icons.assignment_late_rounded,
          title: 'Missing job details',
          subtitle: 'Open this page from an accepted job in the Jobs tab.',
        ),
      ),
    );
  }
}
