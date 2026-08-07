import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';

class JobArrivalStep extends ConsumerWidget {
  const JobArrivalStep({
    super.key,
    required this.state,
    required this.onNavigate,
    required this.onShowSnackBar,
  });

  final JobExecutionState state;
  final VoidCallback onNavigate;
  final Function(String) onShowSnackBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.errorFor(JobExecutionStep.arrival);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final destinationQuery = state.booking?.destinationQuery ?? '';
    final hasLiveLocation = state.currentPosition != null;
    final locationLabel = hasLiveLocation
        ? 'Live GPS fix at ${state.currentPosition!.latitude.toStringAsFixed(5)}, ${state.currentPosition!.longitude.toStringAsFixed(5)}'
        : 'Location will be captured automatically while you are on the way.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locationLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            JobStatusChip(
              icon: hasLiveLocation ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
              label: hasLiveLocation ? 'GPS active' : 'GPS waiting',
            ),
            JobStatusChip(
              icon: Icons.navigation_rounded,
              label: destinationQuery.trim().isEmpty ? 'No route set' : 'Route ready',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.isLoading(JobExecutionStep.arrival))
          const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onNavigate,
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Navigate to customer'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.arrival)
                    ? null
                    : () async {
                        await notifier.markArrived();
                        if (ref.read(jobExecutionProvider).errorFor(JobExecutionStep.arrival) == null) {
                          onShowSnackBar('Ask the customer for their code.');
                        }
                      },
                child: const Text('Mark arrived'),
              ),
            ),
            if (error?.kind == JobExecutionErrorKind.location) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text('Open settings'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ask the customer for their code after you mark arrived. It is not shown in this app.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
