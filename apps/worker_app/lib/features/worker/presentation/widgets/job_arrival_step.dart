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
    final locationLabel = state.isTracking
        ? 'Your location is shared with this customer while you travel to the service address.'
        : 'Share your live location with the customer while travelling. Sharing stops when you arrive.';

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
              icon: state.isTracking
                  ? Icons.gps_fixed_rounded
                  : Icons.gps_not_fixed_rounded,
              label: state.isTracking
                  ? 'Sharing enabled · app open'
                  : 'Trip sharing off',
            ),
            JobStatusChip(
              icon: Icons.navigation_rounded,
              label: destinationQuery.trim().isEmpty
                  ? 'No route set'
                  : 'Route ready',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.trackingError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.trackingError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (state.canOpenTrackingSettings)
                  TextButton(
                    onPressed: state.trackingErrorKind == TrackingErrorKind.gps
                        ? Geolocator.openLocationSettings
                        : Geolocator.openAppSettings,
                    child: const Text('Settings'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.trackingBusy ||
                    (state.trackingStarted && state.trackingError == null)
                ? null
                : () async {
                    if (!state.trackingStarted) {
                      final consent = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Share your trip location?'),
                          content: const Text(
                            'VeeduFix shares your live location with this booking’s customer while this app is open and trip sharing is on. Updates pause when you switch to another app, including navigation, and resume when you return. Sharing stops when you mark that you have arrived.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Not now'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Continue'),
                            ),
                          ],
                        ),
                      );
                      if (consent == true) await notifier.startEnRoute();
                    } else {
                      await notifier.retryLiveTracking();
                    }
                  },
            icon: state.trackingBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(state.trackingStarted &&
                        state.isTracking &&
                        state.trackingError == null
                    ? Icons.gps_fixed_rounded
                    : state.trackingStarted
                        ? state.trackingError == null
                            ? Icons.location_searching_rounded
                            : Icons.refresh_rounded
                        : Icons.share_location_rounded),
            label: Text(state.trackingBusy
                ? 'Starting trip sharing…'
                : state.isTracking && state.trackingError == null
                    ? 'On the way · live while app is open'
                    : state.trackingStarted
                        ? state.trackingError == null
                            ? 'Connecting to live location…'
                            : 'Retry location sharing'
                        : 'Start trip & share location'),
          ),
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
                        if (ref
                                .read(jobExecutionProvider)
                                .errorFor(JobExecutionStep.arrival) ==
                            null) {
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
