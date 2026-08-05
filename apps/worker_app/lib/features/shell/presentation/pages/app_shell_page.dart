import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:marketplace_shared/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:marketplace_shared/features/worker_jobs/presentation/providers/worker_jobs_providers.dart';

class AppShellPage extends ConsumerWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final statsAsync = ref.watch(workerDashboardStatsProvider);
    final unreadNotifications =
        ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;
    final todayJobsCount = statsAsync.valueOrNull?.todayJobs.length ?? 0;
    final destinations = const [
      '/worker',
      '/schedule',
      '/jobs',
      '/earnings',
      '/profile'
    ];

    final matchedIndex = destinations.indexWhere((path) => path == location);
    final index = matchedIndex < 0 ? 0 : matchedIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: index,
                onDestinationSelected: (selected) {
                  context.go(destinations[selected]);
                },
                destinations: [
                  NavigationDestination(
                    icon: _BadgeIcon(
                      icon: Icons.work_outline_rounded,
                      count: unreadNotifications,
                    ),
                    selectedIcon: _BadgeIcon(
                      icon: Icons.work_rounded,
                      count: unreadNotifications,
                    ),
                    label: 'Dashboard',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Schedule',
                  ),
                  NavigationDestination(
                    icon: _BadgeIcon(
                      icon: Icons.assignment_outlined,
                      count: todayJobsCount,
                    ),
                    selectedIcon: _BadgeIcon(
                      icon: Icons.assignment_rounded,
                      count: todayJobsCount,
                    ),
                    label: 'Jobs',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.payments_outlined),
                    selectedIcon: Icon(Icons.payments_rounded),
                    label: 'Earnings',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
  });

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: count > 0 ? Text(count > 99 ? '99+' : '$count') : null,
      child: Icon(icon),
    );
  }
}
