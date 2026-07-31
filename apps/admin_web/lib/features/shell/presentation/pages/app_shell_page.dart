import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:marketplace_shared/marketplace_shared.dart';

class AppShellPage extends ConsumerStatefulWidget {
  const AppShellPage({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends ConsumerState<AppShellPage> {
  bool _isSidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    // Auto-collapse on small screens
    final showExpanded = isDesktop && _isSidebarExpanded;
    final sidebarWidth = showExpanded ? 260.0 : 80.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              border: const Border(right: BorderSide(color: Color(0xFFE5E7EB))),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Area
                    Padding(
                      padding: EdgeInsets.fromLTRB(showExpanded ? 24 : 12, 32, showExpanded ? 24 : 12, 32),
                      child: Row(
                        mainAxisAlignment: showExpanded ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                        children: [
                          if (showExpanded)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VeeduFix',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF0F766E),
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                    fontSize: 22,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ADMIN PANEL',
                                  style: GoogleFonts.inter(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          if (showExpanded)
                            IconButton(
                              icon: const Icon(Icons.menu_open_rounded, size: 20, color: Colors.black54),
                              onPressed: () => setState(() => _isSidebarExpanded = false),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.menu_rounded, size: 24, color: Color(0xFF0F766E)),
                              onPressed: () => setState(() => _isSidebarExpanded = true),
                            ),
                        ],
                      ),
                    ),
                    // Navigation Items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _buildCategoryHeader('Overview', showExpanded),
                          _buildNavItem('/admin', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Dashboard', location, showExpanded),
                          _buildNavItem('/analytics', Icons.insights_outlined, Icons.insights_rounded, 'Analytics', location, showExpanded),
                          
                          _buildCategoryHeader('Operations', showExpanded),
                          _buildNavItem('/ops/overview', Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Health', location, showExpanded),
                          _buildNavItem('/ops/live-jobs', Icons.map_outlined, Icons.map_rounded, 'Live Jobs', location, showExpanded),
                          _buildNavItem('/ops/alerts', Icons.warning_amber_outlined, Icons.warning_rounded, 'Alerts', location, showExpanded, badge: '3'),
                          _buildNavItem('/ops/disputes', Icons.gavel_outlined, Icons.gavel_rounded, 'Disputes', location, showExpanded),

                          _buildCategoryHeader('Workforce', showExpanded),
                          _buildNavItem('/workers', Icons.people_outline_rounded, Icons.people_rounded, 'Directory', location, showExpanded),
                          _buildNavItem('/worker-review', Icons.how_to_reg_outlined, Icons.how_to_reg_rounded, 'Review Queue', location, showExpanded, badge: '12'),

                          _buildCategoryHeader('Marketplace', showExpanded),
                          _buildNavItem('/catalog', Icons.category_outlined, Icons.category_rounded, 'Catalog', location, showExpanded),

                          _buildCategoryHeader('Finance', showExpanded),
                          _buildNavItem('/finance', Icons.account_balance_outlined, Icons.account_balance_rounded, 'Overview', location, showExpanded),
                          _buildNavItem('/finance/payouts', Icons.payments_outlined, Icons.payments_rounded, 'Payouts', location, showExpanded),
                          _buildNavItem('/finance/refunds', Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Refunds', location, showExpanded),
                        ],
                      ),
                    ),
                    // Footer
                    if (showExpanded)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '© 2026 VeeduFix',
                          style: GoogleFonts.inter(
                            color: Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Row(
                        children: [
                          // Global Search
                          Container(
                            width: 300,
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search_rounded, size: 18, color: Colors.black45),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      readOnly: true,
                                      onTap: () => _openQuickLauncher(context),
                                      decoration: InputDecoration(
                                        hintText: 'Search jobs, workers, etc. (Ctrl+K)',
                                        hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.black45),
                                        border: InputBorder.none,
                                        isDense: true,
                                    ),
                                    style: GoogleFonts.inter(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Actions
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black54),
                            onPressed: () => context.go('/ops/alerts'),
                          ),
                          const SizedBox(width: 16),
                          Container(width: 1, height: 24, color: const Color(0xFFE5E7EB)),
                          const SizedBox(width: 16),
                          // Profile
                          TapScale(
                            onTap: () => context.go('/profile'),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                                  child: const Text(
                                    'AD',
                                    style: TextStyle(color: Color(0xFF0F766E), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.black54),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Page Content
                Expanded(
                  child: ClipRect(
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openQuickLauncher(BuildContext context) {
    final actions = [
      _QuickAction('Global Search', '/search', Icons.search_rounded),
      _QuickAction('Dashboard', '/admin', Icons.space_dashboard_rounded),
      _QuickAction('Alerts', '/ops/alerts', Icons.warning_rounded),
      _QuickAction('Support Tickets', '/support-tickets', Icons.support_agent_rounded),
      _QuickAction('Worker Review', '/worker-review', Icons.how_to_reg_rounded),
      _QuickAction('Workers', '/workers', Icons.people_rounded),
      _QuickAction('Catalog', '/catalog', Icons.category_rounded),
      _QuickAction('Finance', '/finance', Icons.account_balance_rounded),
    ];

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Quick launcher'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: actions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final action = actions[index];
                return ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    context.go(action.route);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(String title, bool showExpanded) {
    if (!showExpanded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Divider(color: Color(0xFFE5E7EB), height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.black45,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(String path, IconData icon, IconData activeIcon, String label, String location, bool showExpanded, {String? badge}) {
    final isSelected = location == path || (path != '/admin' && location.startsWith('$path/'));
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: showExpanded ? 16 : 0, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F766E).withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected && !showExpanded ? const Border(left: BorderSide(color: Color(0xFF0F766E), width: 3)) : null,
          ),
          child: showExpanded
              ? Row(
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? const Color(0xFF0F766E) : Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Badge(
                    isLabelVisible: badge != null,
                    label: badge != null ? Text(badge ) : null,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? const Color(0xFF0F766E) : Colors.black54,
                      size: 24,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.route, this.icon);
  final String label;
  final String route;
  final IconData icon;
}
