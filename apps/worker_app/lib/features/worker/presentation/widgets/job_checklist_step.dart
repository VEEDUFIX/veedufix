import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';

class JobChecklistStep extends ConsumerWidget {
  const JobChecklistStep({
    super.key,
    required this.state,
  });

  final JobExecutionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.errorFor(JobExecutionStep.checklist);
    final notifier = ref.read(jobExecutionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!state.checklistLoaded) ...[
          if (state.isLoading(JobExecutionStep.checklist))
            const LinearProgressIndicator(minHeight: 4)
          else
            FilledButton.icon(
              onPressed: () async {
                await notifier.loadChecklistTemplate();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Load checklist'),
            ),
          const SizedBox(height: 12),
        ],
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.checklistItems.isNotEmpty)
          ...state.checklistItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  border: Border.all(
                    color: item.completed
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: CheckboxListTile(
                  value: item.completed,
                  onChanged: state.isLoading(JobExecutionStep.checklist)
                      ? null
                      : (value) async {
                          await notifier.toggleChecklistItem(item.id, value ?? false);
                        },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (item.requiresPhoto)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.photo_camera_outlined, size: 18),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    item.required ? 'Required' : 'Optional',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),
          )
        else
          const PremiumEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No checklist items loaded',
            subtitle: 'The service checklist template will appear here once it loads.',
          ),
        const SizedBox(height: 10),
        Text(
          state.allRequiredChecklistComplete
              ? 'Checklist complete. You can move to after photos.'
              : 'Complete every required item to unlock after photos.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: state.allRequiredChecklistComplete
                    ? const Color(0xFF0F766E)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
