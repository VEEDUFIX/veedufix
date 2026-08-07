import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminQuickActionsPage extends StatelessWidget {
  const AdminQuickActionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4EE),
        surfaceTintColor: Colors.transparent,
        title: Text('Quick actions', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Jump straight to the tasks you use most often.',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _QuickActionTile(
            icon: Icons.support_agent_rounded,
            label: 'Open support tickets',
            onTap: () => context.go('/support-tickets'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.assignment_rounded,
            label: 'Audit logs',
            onTap: () => context.go('/audit-logs'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.warning_rounded,
            label: 'View alerts',
            onTap: () => context.go('/ops/alerts'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.how_to_reg_rounded,
            label: 'Worker review queue',
            onTap: () => context.go('/worker-review'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.account_balance_rounded,
            label: 'Finance overview',
            onTap: () => context.go('/finance'),
          ),
          const SizedBox(height: 24),
          Text('Operational shortcuts', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _QuickActionTile(
            icon: Icons.work_history_rounded,
            label: 'Live jobs',
            onTap: () => context.go('/ops/live-jobs'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.gavel_rounded,
            label: 'Disputes',
            onTap: () => context.go('/ops/disputes'),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.campaign_rounded,
            label: 'Broadcast push',
            onTap: () => context.go('/push'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: Colors.black.withValues(alpha: 0.03),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: const Color(0xFF0F766E)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
