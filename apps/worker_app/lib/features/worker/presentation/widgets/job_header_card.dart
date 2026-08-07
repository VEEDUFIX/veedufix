import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/job_execution_provider.dart';

class JobHeaderCard extends StatelessWidget {
  const JobHeaderCard({
    super.key,
    required this.state,
    required this.accentColor,
  });

  final JobExecutionState state;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final booking = state.booking!;
    final progress = state.currentStep.clamp(1, 7) / 7;
    final completed = state.summary != null;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  ),
                  child: Icon(
                    Icons.assignment_rounded,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${booking.customerName} • ${booking.locationLabel}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              booking.summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PremiumStatCard(
                    label: 'Progress',
                    value: '${state.currentStep.clamp(1, 7)} of 7',
                    icon: Icons.route_rounded,
                    accentColor: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PremiumStatCard(
                    label: 'Payout',
                    value: booking.earningsLabel,
                    icon: Icons.payments_rounded,
                    accentColor: const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              completed
                  ? 'Flow complete'
                  : 'Step ${state.currentStep.clamp(1, 7)} of 7',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
