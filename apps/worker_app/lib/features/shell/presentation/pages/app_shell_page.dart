import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:marketplace_shared/features/worker_jobs/presentation/providers/worker_jobs_providers.dart';
import 'package:marketplace_shared/core/storage/app_locale_provider.dart';

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
        minimum: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.45),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 68,
              backgroundColor: const Color(0xFFFFFCF7),
              elevation: 0,
              indicatorColor: const Color(0x1FC8A75A),
              indicatorShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF17120D)
                      : const Color(0xFF766F66),
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 23,
                  color: selected
                      ? const Color(0xFFC8A75A)
                      : const Color(0xFF766F66),
                );
              }),
            ),
            child: NavigationBar(
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
                  label: appText(context, 'Dashboard', 'முகப்பு'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_today_outlined),
                  selectedIcon: const Icon(Icons.calendar_month_rounded),
                  label: appText(context, 'Schedule', 'அட்டவணை'),
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
                  label: appText(context, 'Jobs', 'வேலைகள்'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.payments_outlined),
                  selectedIcon: const Icon(Icons.payments_rounded),
                  label: appText(context, 'Earnings', 'வருமானம்'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.person_outline_rounded),
                  selectedIcon: const Icon(Icons.person_rounded),
                  label: appText(context, 'Profile', 'சுயவிவரம்'),
                ),
              ],
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
