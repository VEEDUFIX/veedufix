import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../admin/presentation/widgets/admin_surface.dart';

class FinanceHomePage extends StatelessWidget {
  const FinanceHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Finance',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const AdminSurfacePanel(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ledger and recovery queues',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: kAdminInk,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Track worker payouts and customer refunds from one finance workspace.',
                    style: TextStyle(
                      color: kAdminMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 360,
                child: AdminSurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: Color(0xFF0F766E)),
                    ),
                    title: const Text(
                      'Payouts ledger',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Review worker payout status and retry failed transfers.',
                    ),
                    trailing: TextButton(
                      onPressed: () => context.go('/finance/payouts'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 360,
                child: AdminSurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Color(0xFFEF4444)),
                    ),
                    title: const Text(
                      'Refunds ledger',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Review refund processing and retry failures.',
                    ),
                    trailing: TextButton(
                      onPressed: () => context.go('/finance/refunds'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
