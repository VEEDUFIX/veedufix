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
      bottomNavigationBar: VeeduFixBottomNav(
        selectedIndex: index,
        onDestinationSelected: (selected) => context.go(destinations[selected]),
        destinations: [
          VeeduFixNavDestination(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: appText(context, 'Home', 'முகப்பு'),
          ),
          VeeduFixNavDestination(
            icon: Icons.search_rounded,
            selectedIcon: Icons.search_rounded,
            label: appText(context, 'Search', 'தேடல்'),
          ),
          VeeduFixNavDestination(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: appText(context, 'Bookings', 'முன்பதிவுகள்'),
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
