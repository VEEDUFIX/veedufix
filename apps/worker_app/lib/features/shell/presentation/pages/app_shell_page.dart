import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/core/storage/app_locale_provider.dart';

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
                  icon: const Icon(Icons.work_outline_rounded),
                  selectedIcon: const Icon(Icons.work_rounded),
                  label: appText(context, 'Dashboard', 'முகப்பு'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_today_outlined),
                  selectedIcon: const Icon(Icons.calendar_month_rounded),
                  label: appText(context, 'Schedule', 'அட்டவணை'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.assignment_outlined),
                  selectedIcon: const Icon(Icons.assignment_rounded),
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
