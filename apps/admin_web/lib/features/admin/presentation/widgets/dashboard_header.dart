import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class DashboardHeader extends StatelessWidget {
  final bool isCompact;

  const DashboardHeader({
    super.key,
    required this.isCompact,
  });

  void _openDashboardActions(BuildContext context) {
    context.push('/admin/quick-actions');
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Monitor revenue, support, worker approvals, and marketplace health.',
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openDashboardActions(context),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Customize'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Monitor revenue, support, worker approvals, and marketplace health.',
              style: GoogleFonts.inter(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => _openDashboardActions(context),
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Customize'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
