import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

class AppShellPage extends StatelessWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final destinations = const ['/worker', '/schedule', '/jobs', '/earnings', '/profile'];

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
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35)),
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
                  const NavigationDestination(
                    icon: Badge(
                      label: Text('2'),
                      child: Icon(Icons.work_outline_rounded),
                    ),
                    selectedIcon: Badge(
                      label: Text('2'),
                      child: Icon(Icons.work_rounded),
                    ),
                    label: 'Dashboard',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Schedule',
                  ),
                  const NavigationDestination(
                    icon: Badge(
                      child: Icon(Icons.assignment_outlined),
                    ),
                    selectedIcon: Badge(
                      child: Icon(Icons.assignment_rounded),
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
