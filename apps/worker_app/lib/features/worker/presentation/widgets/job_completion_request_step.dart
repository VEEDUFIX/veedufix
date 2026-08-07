import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';

class JobCompletionRequestStep extends ConsumerWidget {
  const JobCompletionRequestStep({
    super.key,
    required this.state,
  });

  final JobExecutionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.errorFor(JobExecutionStep.completionRequest);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final blocker = state.completionBlocker;
    final ready = state.canRequestCompletionOtp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (blocker != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocker.message,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (blocker.missingPhotos)
                  Text(
                    'Missing photos: after photos are still required.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (blocker.missingItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Missing items:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...blocker.missingItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('• $item'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (!ready || state.isLoading(JobExecutionStep.completionRequest))
              ? null
              : () async {
                  await notifier.requestCompletionOtp();
                },
          icon: const Icon(Icons.key_rounded),
          label: state.isLoading(JobExecutionStep.completionRequest)
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Request completion code'),
        ),
        const SizedBox(height: 10),
        Text(
          ready
              ? 'The customer can now share the final completion code.'
              : 'Finish the checklist and after photos before requesting the final code.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
