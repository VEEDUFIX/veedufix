import 'dart:io';

import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/job_execution_provider.dart';

class JobPhotoDraftTile extends StatelessWidget {
  const JobPhotoDraftTile({
    super.key,
    required this.draft,
    required this.onRetry,
    required this.accentColor,
  });

  final JobExecutionPhotoDraft draft;
  final VoidCallback? onRetry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = draft.hasFailed
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
        : draft.isQueued
            ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
            : accentColor.withValues(alpha: 0.16);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 52,
            width: 52,
            child: Image.file(
              File(draft.file.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          draft.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          draft.hasFailed
              ? draft.errorMessage ?? 'Upload failed'
              : draft.isUploaded
                  ? 'Uploaded successfully'
                  : draft.isQueued
                      ? 'Queued — will upload when back online'
                      : draft.uploading
                          ? 'Preparing photo…'
                          : 'Waiting to upload',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onRetry != null
            ? TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              )
            : draft.isUploaded
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                : draft.isQueued
                    ? const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFFF59E0B),
                      )
                    : draft.uploading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pending_outlined),
      ),
    );
  }
}
