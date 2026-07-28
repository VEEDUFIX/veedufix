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
    
    // We define our routes as a list of records for easy mapping
    final destinations = [
      (path: '/admin', icon: Icons.space_dashboard_outlined, activeIcon: Icons.space_dashboard_rounded, label: 'Dashboard'),
      (path: '/analytics', icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Analytics'),
      (path: '/ops/overview', icon: Icons.monitor_heart_outlined, activeIcon: Icons.monitor_heart_rounded, label: 'Operations'),
      (path: '/profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VeeduFix',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: const Color(0xFF0F766E),
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ADMIN PANEL',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
                // Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final isSelected = location == item.path || (item.path == '/ops/overview' && location.startsWith('/ops/'));
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () => context.go(item.path),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F766E).withValues(alpha: 0.08) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  color: isSelected ? const Color(0xFF0F766E) : Colors.black54,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '© 2026 VeeduFix',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: ClipRect(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
