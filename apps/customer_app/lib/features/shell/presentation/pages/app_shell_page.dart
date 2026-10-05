import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    const destinations = ['/app', '/search', '/bookings', '/profile'];
    final matchedIndex = destinations.indexWhere((path) => path == location);
    final index = matchedIndex < 0 ? 0 : matchedIndex;

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) => context.go(destinations[selected]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: appText(context, 'Home', 'முகப்பு'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            label: appText(context, 'Search', 'தேடல்'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: appText(context, 'Bookings', 'முன்பதிவுகள்'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: appText(context, 'Profile', 'சுயவிவரம்'),
          ),
        ],
      ),
    );
  }
}
