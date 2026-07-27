import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../data/worker_directory_api.dart';

class WorkerDirectoryDetailPage extends ConsumerStatefulWidget {
  const WorkerDirectoryDetailPage({
    super.key,
    required this.profileId,
    this.initialProfile,
  });

  final String profileId;
  final WorkerDirectoryProfile? initialProfile;

  @override
  ConsumerState<WorkerDirectoryDetailPage> createState() =>
      _WorkerDirectoryDetailPageState();
}

class _WorkerDirectoryDetailPageState
    extends ConsumerState<WorkerDirectoryDetailPage> {
  late final WorkerDirectoryApi _api;
  late Future<WorkerDirectoryHistoryResponse> _historyFuture;
  WorkerDirectoryProfile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = WorkerDirectoryApi(ref.read(apiClientProvider).dio);
    _profile = widget.initialProfile;
    _historyFuture = _loadHistory();
  }

  Future<WorkerDirectoryHistoryResponse> _loadHistory() {
    return _api.fetchHistory(widget.profileId);
  }

  Future<void> _reload() async {
    setState(() {
      _historyFuture = _loadHistory();
    });
    final history = await _historyFuture;
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = history.worker;
    });
  }

  Future<void> _runMutation(
      Future<WorkerDirectoryProfile> Function() action) async {
    setState(() => _busy = true);
    try {
      final updatedProfile = await action();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updatedProfile);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _showReasonDialog({
    required String title,
    required String label,
    required String actionLabel,
    required String helperText,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 480,
              child: TextFormField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: label,
                  helperText: helperText,
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 3) {
                    return 'Enter at least 3 characters';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return reason;
  }

  Future<void> _suspend(WorkerDirectoryProfile profile) async {
    final reason = await _showReasonDialog(
      title: 'Suspend worker',
      label: 'Suspension reason',
      actionLabel: 'Suspend',
      helperText: 'Use a clear note for the moderation record.',
    );
    if (reason == null) {
      return;
    }
    await _runMutation(() => _api.suspend(profile.id, reason));
  }

  Future<void> _reinstate(WorkerDirectoryProfile profile) async {
    final note = await _showReasonDialog(
      title: 'Reinstate worker',
      label: 'Reinstatement note',
      actionLabel: 'Reinstate',
      helperText:
          'Add a short admin note explaining why the account was restored.',
    );
    if (note == null) {
      return;
    }
    await _runMutation(() => _api.reinstate(profile.id, note));
  }

  Future<void> _openUrl(String url) async {
    final canOpen =
        await launchUrlString(url, mode: LaunchMode.platformDefault);
    if (!canOpen && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open document.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F5EC),
        appBar: AppBar(title: const Text('Worker directory')),
        body: const Center(
          child: PremiumEmptyState(
            icon: Icons.badge_rounded,
            title: 'Worker details unavailable',
            subtitle:
                'Open this page from the worker directory so the profile can be loaded.',
          ),
        ),
      );
    }

    final accent = switch (profile.onboardingStatus) {
      'approved' => const Color(0xFF0F766E),
      'suspended' => const Color(0xFFB45309),
      'rejected' => const Color(0xFFEF4444),
      _ => const Color(0xFFF59E0B),
    };
    final canSuspend = profile.onboardingStatus == 'approved';
    final canReinstate = profile.onboardingStatus == 'suspended';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: const Text('Worker directory'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<WorkerDirectoryHistoryResponse>(
          future: _historyFuture,
          builder: (context, snapshot) {
            final history = snapshot.data;
            final worker = history?.worker ?? profile;
            final ratings = history?.ratings ?? const <WorkerDirectoryRating>[];
            final statusEvents =
                history?.statusEvents ?? const <WorkerDirectoryStatusEvent>[];
            final noShowCount = history?.noShowCount ?? worker.noShowCount;

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 72,
                              width: 72,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(Icons.badge_rounded,
                                  color: accent, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    worker.displayName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${worker.cityLabel} - ${worker.onboardingStatus.replaceAll('_', ' ')}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            PremiumStatCard(
                              label: 'Rating',
                              value: worker.ratingAvg.toStringAsFixed(1),
                              icon: Icons.star_rounded,
                              accentColor: const Color(0xFFF59E0B),
                            ),
                            PremiumStatCard(
                              label: 'Completed jobs',
                              value: '${worker.jobsCompletedCount}',
                              icon: Icons.task_alt_rounded,
                              accentColor: const Color(0xFF2563EB),
                            ),
                            PremiumStatCard(
                              label: 'No-shows',
                              value: '$noShowCount',
                              icon: Icons.warning_amber_rounded,
                              accentColor: const Color(0xFFB45309),
                            ),
                            PremiumStatCard(
                              label: 'Status',
                              value:
                                  worker.onboardingStatus.replaceAll('_', ' '),
                              icon: Icons.verified_user_rounded,
                              accentColor: accent,
                            ),
                          ],
                        ),
                        if (_busy) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                        if (canSuspend || canReinstate) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (canSuspend)
                                FilledButton.icon(
                                  onPressed:
                                      _busy ? null : () => _suspend(worker),
                                  icon: const Icon(Icons.pause_circle_rounded),
                                  label: const Text('Suspend'),
                                ),
                              if (canReinstate)
                                FilledButton.icon(
                                  onPressed:
                                      _busy ? null : () => _reinstate(worker),
                                  icon: const Icon(
                                      Icons.play_circle_fill_rounded),
                                  label: const Text('Reinstate Worker'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 420,
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recent ratings',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              if (ratings.isEmpty)
                                const PremiumEmptyState(
                                  icon: Icons.star_outline_rounded,
                                  title: 'No ratings yet',
                                  subtitle:
                                      'Ratings will appear here after the worker completes jobs.',
                                )
                              else
                                ...ratings.map(
                                  (rating) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _RatingTile(rating: rating),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status history',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              if (statusEvents.isEmpty)
                                const PremiumEmptyState(
                                  icon: Icons.history_rounded,
                                  title: 'No history recorded',
                                  subtitle:
                                      'Status changes will show up here when moderation actions exist.',
                                )
                              else
                                ...statusEvents.map(
                                  (event) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _StatusEventTile(event: event),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 420,
                      child: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profile details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              _DetailRow(label: 'Worker ID', value: worker.id),
                              _DetailRow(
                                  label: 'No-show count',
                                  value: '$noShowCount'),
                              _DetailRow(
                                  label: 'Reviewed by',
                                  value: worker.reviewedBy ?? 'Not reviewed'),
                              _DetailRow(
                                label: 'Reviewed at',
                                value: worker.reviewedAt != null
                                    ? worker.reviewedAt!.toLocal().toString()
                                    : 'Not reviewed',
                              ),
                              if ((worker.rejectionReason ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _DetailRow(
                                    label: 'Note',
                                    value: worker.rejectionReason!),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hasDocumentLinks(worker)) ...[
                  const SizedBox(height: 16),
                  PremiumGlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documents',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 12),
                          if ((worker.avatarUrl ?? '').trim().isNotEmpty)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.image_rounded),
                              title: const Text('Profile image'),
                              subtitle: const Text(
                                  'Open the linked image in a browser.'),
                              trailing: TextButton(
                                onPressed: () =>
                                    _openUrl(worker.avatarUrl!.trim()),
                                child: const Text('Open'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _hasDocumentLinks(WorkerDirectoryProfile worker) {
    return (worker.avatarUrl ?? '').trim().isNotEmpty;
  }
}

class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.rating});

  final WorkerDirectoryRating rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DED0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < rating.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFF59E0B),
                  size: 18,
                ),
              ),
              const Spacer(),
              Text(
                rating.bookingCode,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            rating.customerName,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          if ((rating.comment ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rating.comment!.trim()),
          ],
          const SizedBox(height: 8),
          Text(
            rating.createdAt.toLocal().toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusEventTile extends StatelessWidget {
  const _StatusEventTile({required this.event});

  final WorkerDirectoryStatusEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DED0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.type.replaceAll('_', ' '),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text('Status: ${event.status.replaceAll('_', ' ')}'),
          if ((event.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(event.note!.trim()),
          ],
          if ((event.reviewedBy ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('By: ${event.reviewedBy!.trim()}'),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
