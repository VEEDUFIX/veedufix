import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/offline/connectivity_service.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';
import 'job_photo_draft_tile.dart';

class JobPhotoStep extends ConsumerWidget {
  const JobPhotoStep({
    super.key,
    required this.state,
    required this.type,
  });

  final JobExecutionState state;
  final JobExecutionPhotoType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBefore = type == JobExecutionPhotoType.before;
    final items = isBefore ? state.beforePhotos : state.afterPhotos;
    final step = isBefore ? JobExecutionStep.beforePhotos : JobExecutionStep.afterPhotos;
    final error = state.errorFor(step);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final canUpload = isBefore || state.allRequiredChecklistComplete;
    final preparing = items.any((draft) => draft.uploading && !draft.isUploaded && draft.errorMessage == null);
    final queuedCount = items.where((d) => d.isQueued).length;
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Offline / queued banner ──────────────────────────────────────
        if (!isOnline || queuedCount > 0)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                  : const Color(0xFF6B7280).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              border: Border.all(
                color: isOnline
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                    : const Color(0xFF6B7280).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline ? Icons.cloud_sync_rounded : Icons.wifi_off_rounded,
                  size: 18,
                  color: isOnline ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? '$queuedCount photo${queuedCount == 1 ? '' : 's'} uploading now…'
                        : queuedCount > 0
                            ? 'Offline — $queuedCount photo${queuedCount == 1 ? '' : 's'} will upload when you reconnect.'
                            : 'You\'re offline — photos will queue automatically.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isOnline ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                        ),
                  ),
                ),
              ],
            ),
          ),

        if (!canUpload && !isBefore)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Text(
              'Finish the checklist before uploading after photos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!canUpload && !isBefore) const SizedBox(height: 12),
        if (error != null) ...[
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.isLoading(step)) ...[
          const LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  preparing ? 'Preparing photo...' : 'Uploading photos...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (!canUpload || state.isLoading(step))
              ? null
              : () async {
                  await notifier.pickAndUploadPhotos(type);
                },
          icon: Icon(isBefore ? Icons.camera_alt_rounded : Icons.photo_library_rounded),
          label: Text(isBefore ? 'Add before photos' : 'Add after photos'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          PremiumEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No ${isBefore ? 'before' : 'after'} photos yet',
            subtitle: 'Add up to five photos to document this step.',
          )
        else
          Column(
            children: items
                .map(
                  (draft) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: JobPhotoDraftTile(
                      draft: draft,
                      onRetry: draft.hasFailed
                          ? () async {
                              await notifier.retryPhoto(type, draft.id);
                            }
                          : null,
                      accentColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}
