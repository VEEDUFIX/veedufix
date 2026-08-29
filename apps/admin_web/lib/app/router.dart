import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../features/admin/presentation/pages/action_inbox_page.dart';
import '../features/admin/presentation/pages/admin_quick_actions_page.dart';
import '../features/admin/presentation/pages/analytics_page.dart';
import '../features/catalog/presentation/pages/catalog_manager_page.dart';
import '../features/service_areas/presentation/pages/service_area_manager_page.dart';
import '../features/finance/presentation/pages/finance_home_page.dart';
import '../features/finance/presentation/pages/payouts_ledger_page.dart';
import '../features/finance/presentation/pages/refunds_ledger_page.dart';
import '../features/finance/presentation/pages/tax_summary_page.dart';
import '../features/finance/data/finance_api.dart';
import '../features/ops/presentation/pages/ops_alerts_page.dart';
import '../features/ops/data/ops_api.dart';
import '../features/ops/presentation/pages/dispute_detail_page.dart';
import '../features/ops/presentation/pages/disputes_queue_page.dart';
import '../features/ops/presentation/pages/ops_live_jobs_page.dart';
import '../features/ops/presentation/pages/ops_overview_page.dart';
import '../features/ops/presentation/pages/god_mode_map_page.dart';
import '../features/worker_directory/presentation/pages/worker_directory_detail_page.dart';
import '../features/worker_directory/presentation/pages/worker_directory_page.dart';
import '../features/worker_directory/data/worker_directory_api.dart';
import '../features/worker_review/data/worker_review_api.dart';
import '../features/worker_review/presentation/pages/worker_review_detail_page.dart';
import '../features/worker_review/presentation/pages/worker_review_queue_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/admin/presentation/pages/customer_management_page.dart';
import '../features/admin/presentation/pages/customer_detail_page.dart';
import '../features/admin/presentation/pages/booking_management_page.dart';
import '../features/admin/presentation/pages/booking_detail_page.dart';
import '../features/admin/presentation/pages/coupon_manager_page.dart';
import '../features/admin/presentation/pages/reports_page.dart';
import '../features/admin/presentation/pages/push_sender_page.dart';
import '../features/admin/presentation/pages/audit_logs_page.dart';
import '../features/admin/presentation/pages/global_search_page.dart';
import '../features/admin/presentation/pages/support_tickets_page.dart';
import '../features/admin/presentation/pages/platform_settings_page.dart';
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

      // Enforce ADMIN role — an authenticated CUSTOMER or WORKER must not
      // access admin routes even if they hold a valid token.
      if (session.user.role != 'ADMIN') {
        return '/login';
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
            path: '/admin/action-inbox',
            builder: (context, state) => const AdminActionInboxPage(),
          ),
          GoRoute(
            path: '/admin/quick-actions',
            builder: (context, state) => const AdminQuickActionsPage(),
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
            path: '/catalog/categories/:categoryId',
            builder: (context, state) {
              final categoryId = state.pathParameters['categoryId'] ?? '';
              return CategoryDetailPage(categoryId: categoryId);
            },
          ),
          GoRoute(
            path: '/catalog/subcategories/:subcategoryId',
            builder: (context, state) {
              final subcategoryId = state.pathParameters['subcategoryId'] ?? '';
              return SubcategoryDetailPage(subcategoryId: subcategoryId);
            },
          ),
          GoRoute(
            path: '/catalog/services/:serviceId',
            builder: (context, state) {
              final serviceId = state.pathParameters['serviceId'] ?? '';
              return ServiceDetailPage(serviceId: serviceId);
            },
          ),
          GoRoute(
            path: '/service-areas',
            builder: (context, state) => const ServiceAreaManagerPage(),
          ),
          GoRoute(
            path: '/service-areas/:areaId',
            builder: (context, state) {
              final areaId = state.pathParameters['areaId'] ?? '';
              return ServiceAreaDetailPage(areaId: areaId);
            },
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
            path: '/finance/payouts/:payoutId',
            builder: (context, state) {
              final payoutId = state.pathParameters['payoutId'] ?? '';
              final initialPayout = state.extra is FinancePayoutItem ? state.extra as FinancePayoutItem : null;
              return PayoutDetailPage(
                payoutId: payoutId,
                initialPayout: initialPayout,
              );
            },
          ),
          GoRoute(
            path: '/finance/refunds',
            builder: (context, state) => const RefundsLedgerPage(),
          ),
          GoRoute(
            path: '/finance/tax-summary',
            builder: (context, state) => const TaxSummaryPage(),
          ),
          GoRoute(
            path: '/finance/refunds/:refundId',
            builder: (context, state) {
              final refundId = state.pathParameters['refundId'] ?? '';
              final initialRefund = state.extra is FinanceRefundItem ? state.extra as FinanceRefundItem : null;
              return RefundDetailPage(
                refundId: refundId,
                initialRefund: initialRefund,
              );
            },
          ),
          GoRoute(
            path: '/platform-settings',
            builder: (context, state) => const PlatformSettingsPage(),
          ),
          GoRoute(
            path: '/platform-settings/commissions/:commissionId',
            builder: (context, state) {
              final commissionId = state.pathParameters['commissionId'] ?? '';
              return CommissionDetailPage(commissionId: commissionId);
            },
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
            path: '/ops/live-jobs/:bookingId',
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId'] ?? '';
              final initialJob = state.extra is OpsLiveJob ? state.extra as OpsLiveJob : null;
              return OpsLiveJobDetailPage(
                bookingId: bookingId,
                initialJob: initialJob,
              );
            },
          ),
          GoRoute(
            path: '/ops/alerts',
            builder: (context, state) => const OpsAlertsPage(),
          ),
          GoRoute(
            path: '/ops/alerts/:alertId',
            builder: (context, state) {
              final alertId = state.pathParameters['alertId'] ?? '';
              final initialAlert = state.extra is OpsAlert ? state.extra as OpsAlert : null;
              return OpsAlertDetailPage(
                alertId: alertId,
                initialAlert: initialAlert,
              );
            },
          ),
          GoRoute(
            path: '/ops/map',
            builder: (context, state) => const GodModeMapPage(),
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
          GoRoute(
            path: '/customers',
            builder: (context, state) {
              final search = state.uri.queryParameters['search'] ?? '';
              return CustomerManagementPage(initialSearch: search);
            },
          ),
          GoRoute(
            path: '/customers/:customerId',
            builder: (context, state) {
              final customerId = state.pathParameters['customerId'] ?? '';
              return AdminCustomerDetailPage(customerId: customerId);
            },
          ),
          GoRoute(
            path: '/admin-bookings',
            builder: (context, state) {
              final search = state.uri.queryParameters['search'] ?? '';
              return BookingManagementPage(initialSearch: search);
            },
          ),
          GoRoute(
            path: '/admin-bookings/:bookingId',
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId'] ?? '';
              return AdminBookingDetailPage(bookingId: bookingId);
            },
          ),
          GoRoute(
            path: '/coupons',
            builder: (context, state) => const CouponManagerPage(),
          ),
          GoRoute(
            path: '/coupons/:couponId',
            builder: (context, state) {
              final couponId = state.pathParameters['couponId'] ?? '';
              final initialCoupon = state.extra is AdminCoupon ? state.extra as AdminCoupon : null;
              return CouponDetailPage(
                couponId: couponId,
                initialCoupon: initialCoupon,
              );
            },
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/push',
            builder: (context, state) => const PushSenderPage(),
          ),
          GoRoute(
            path: '/push/broadcasts/:broadcastId',
            builder: (context, state) {
              final broadcastId = state.pathParameters['broadcastId'] ?? '';
              final initialBroadcast = state.extra is AdminBroadcastSummary
                  ? state.extra as AdminBroadcastSummary
                  : null;
              return BroadcastDetailPage(
                broadcastId: broadcastId,
                initialBroadcast: initialBroadcast,
              );
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              return AdminGlobalSearchPage(initialQuery: query);
            },
          ),
          GoRoute(
            path: '/support-tickets',
            builder: (context, state) {
              final search = state.uri.queryParameters['search'] ?? '';
              return SupportTicketsPage(initialSearch: search);
            },
          ),
          GoRoute(
            path: '/support-tickets/:ticketId',
            builder: (context, state) {
              final ticketId = state.pathParameters['ticketId'] ?? '';
              return SupportTicketDetailPage(ticketId: ticketId);
            },
          ),
          GoRoute(
            path: '/audit-logs',
            builder: (context, state) {
              final search = state.uri.queryParameters['search'] ?? '';
              return AuditLogsPage(initialSearch: search);
            },
          ),
          GoRoute(
            path: '/audit-logs/:logId',
            builder: (context, state) {
              final logId = state.pathParameters['logId'] ?? '';
              final initialLog = state.extra is AdminAuditLogEntry ? state.extra as AdminAuditLogEntry : null;
              return AuditLogDetailPage(
                logId: logId,
                initialLog: initialLog,
              );
            },
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
