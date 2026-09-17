import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AppShellPage extends StatelessWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    const destinations = ['/app', '/bookings', '/profile'];
    final matchedIndex = destinations.indexWhere((path) => path == location);
    final index = matchedIndex < 0 ? 0 : matchedIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: Color(0xFFE8E5DE),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  label: 'Home',
                  activeIcon: Icons.explore_rounded,
                  inactiveIcon: Icons.explore_outlined,
                  isSelected: index == 0,
                  destination: destinations[0],
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Bookings',
                  activeIcon: Icons.receipt_long_rounded,
                  inactiveIcon: Icons.receipt_long_outlined,
                  isSelected: index == 1,
                  destination: destinations[1],
                ),
              ),
              Expanded(
                child: _NavItem(
                  label: 'Profile',
                  activeIcon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  isSelected: index == 2,
                  destination: destinations[2],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.isSelected,
    required this.destination,
  });

  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool isSelected;
  final String destination;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFC6A769);
    const inactiveColor = Color(0xFF999999);
    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go(destination),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
