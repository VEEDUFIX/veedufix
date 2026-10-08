import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

const _workerShellDestinations = [
  '/worker',
  '/schedule',
  '/jobs',
  '/earnings',
  '/profile',
];

int workerShellDestinationIndexForLocation(String location) {
  final index = _workerShellDestinations.indexWhere(
    (path) => location == path || location.startsWith('$path/'),
  );
  return index < 0 ? 0 : index;
}

class AppShellPage extends StatelessWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    const destinations = _workerShellDestinations;
    final index = workerShellDestinationIndexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: VeeduFixBottomNav(
        selectedIndex: index,
        onDestinationSelected: (selected) => context.go(destinations[selected]),
        destinations: [
          VeeduFixNavDestination(
            icon: Icons.work_outline_rounded,
            selectedIcon: Icons.work_rounded,
            label: appText(context, 'Dashboard', 'முகப்பு'),
          ),
          VeeduFixNavDestination(
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_month_rounded,
            label: appText(context, 'Schedule', 'அட்டவணை'),
          ),
          VeeduFixNavDestination(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: appText(context, 'Jobs', 'வேலைகள்'),
          ),
          VeeduFixNavDestination(
            icon: Icons.payments_outlined,
            selectedIcon: Icons.payments_rounded,
            label: appText(context, 'Earnings', 'வருமானம்'),
          ),
          VeeduFixNavDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: appText(context, 'Profile', 'சுயவிவரம்'),
          ),
        ],
      ),
    );
  }
}
