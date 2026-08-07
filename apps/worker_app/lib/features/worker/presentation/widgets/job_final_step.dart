import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';

class JobFinalStep extends ConsumerWidget {
  const JobFinalStep({
    super.key,
    required this.state,
    required this.controller,
    required this.onShowSnackBar,
  });

  final JobExecutionState state;
  final TextEditingController controller;
  final Function(String) onShowSnackBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.errorFor(JobExecutionStep.completionOtp);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final summary = state.summary;
    final isExpired = error?.kind == JobExecutionErrorKind.otpExpired;

    if (summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PremiumStatCard(
                  label: 'Earnings',
                  value: summary.earningsLabel,
                  icon: Icons.payments_rounded,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Completed',
                  value: summary.completedAtLabel,
                  icon: Icons.verified_rounded,
                  accentColor: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/jobs?tab=completed'),
            child: const Text('Back to completed jobs'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: '4-digit completion code',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.completionOtp)
                    ? null
                    : () async {
                        final code = controller.text.trim();
                        if (code.length != 4) {
                          onShowSnackBar('Enter the 4-digit completion code.');
                          return;
                        }
                        await notifier.verifyCompletionOtp(code);
                      },
                child: state.isLoading(JobExecutionStep.completionOtp)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify completion code'),
              ),
            ),
            if (isExpired) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: state.isLoading(JobExecutionStep.completionOtp)
                    ? null
                    : () async {
                        await notifier.requestCompletionOtp();
                      },
                child: const Text('Request new code'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'After verification, the job moves to completed and the earnings summary appears here.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
