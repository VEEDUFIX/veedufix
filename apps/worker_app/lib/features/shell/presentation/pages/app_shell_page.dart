import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final destinations = const ['/worker', '/jobs', '/earnings', '/profile'];

    final matchedIndex = destinations.indexWhere((path) => path == location);
    final index = matchedIndex < 0 ? 0 : matchedIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) {
          context.go(destinations[selected]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.work_outline_rounded),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments_rounded),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
