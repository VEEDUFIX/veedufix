import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../data/worker_review_api.dart';

class WorkerReviewDetailPage extends ConsumerStatefulWidget {
  const WorkerReviewDetailPage({
    super.key,
    required this.profileId,
    this.initialProfile,
  });

  final String profileId;
  final WorkerReviewProfile? initialProfile;

  @override
  ConsumerState<WorkerReviewDetailPage> createState() => _WorkerReviewDetailPageState();
}

class _WorkerReviewDetailPageState extends ConsumerState<WorkerReviewDetailPage> {
  late final WorkerReviewApi _api;
  WorkerReviewProfile? _profile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = WorkerReviewApi(ref.read(apiClientProvider).dio);
    _profile = widget.initialProfile;
  }

  Future<void> _runMutation(Future<WorkerReviewProfile> Function() action) async {
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

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Approve worker'),
          content: const Text('Approve this worker application and activate their profile?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await _runMutation(() => _api.approve(widget.profileId));
  }

  Future<void> _reject() async {
    final reason = await _showReasonDialog(
      title: 'Reject worker',
      label: 'Reason for rejection',
      actionLabel: 'Reject',
      helperText: 'Explain what needs to be corrected before the worker can resubmit.',
    );
    if (reason == null) {
      return;
    }
    await _runMutation(() => _api.reject(widget.profileId, reason));
  }

  Future<void> _suspend() async {
    final reason = await _showReasonDialog(
      title: 'Suspend worker',
      label: 'Suspension reason',
      actionLabel: 'Suspend',
      helperText: 'This is usually used for approved workers who need to be paused later.',
    );
    if (reason == null) {
      return;
    }
    await _runMutation(() => _api.suspend(widget.profileId, reason));
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

  Future<void> _openUrl(String url) async {
    final canOpen = await launchUrlString(url, mode: LaunchMode.platformDefault);
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
        appBar: AppBar(title: const Text('Worker review')),
        body: const Center(
          child: PremiumEmptyState(
            icon: Icons.badge_rounded,
            title: 'Review details unavailable',
            subtitle: 'Open this page from the worker review queue so the profile can be loaded.',
          ),
        ),
      );
    }

    final requestedCategories = profile.requestedCategoryNames;
    final isApproved = profile.onboardingStatus == 'approved';
    final canSuspend = isApproved;
    final accent = switch (profile.onboardingStatus) {
      'approved' => const Color(0xFF0F766E),
      'rejected' => const Color(0xFFEF4444),
      'suspended' => const Color(0xFF64748B),
      _ => const Color(0xFFF59E0B),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker review'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _SurfaceCard(
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
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        ),
                        child: Icon(Icons.badge_rounded, color: accent, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${profile.cityLabel} - ${profile.onboardingStatus.replaceAll('_', ' ')}',
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
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StatusChip(label: profile.submittedShortDate, accent: accent),
                      _StatusChip(label: requestedCategories.isEmpty ? 'No skills submitted' : '${requestedCategories.length} requested categories', accent: const Color(0xFF2563EB)),
                      _StatusChip(label: profile.maskedAadhaar, accent: const Color(0xFF0F766E)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(
            title: 'Personal details',
            subtitle: 'Identity and location details submitted by the worker.',
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'Full name', value: profile.fullName ?? 'Not provided'),
                  _DetailRow(label: 'Date of birth', value: _formatDate(profile.dateOfBirth)),
                  _DetailRow(label: 'Address', value: profile.addressLine1 ?? 'Not provided'),
                  _DetailRow(label: 'City', value: profile.cityLabel),
                  _DetailRow(label: 'Pincode', value: profile.pincode ?? 'Not provided'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(
            title: 'Identity verification',
            subtitle: 'Masked Aadhaar and the uploaded document for manual review.',
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'Aadhaar', value: profile.maskedAadhaar),
                  const SizedBox(height: 6),
                  if (profile.hasAadhaarDoc)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              try {
                                final url = await _api.fetchAadhaarDocUrl(profile.id);
                                await _openUrl(url);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Unable to open Aadhaar document.')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open Aadhaar document'),
                    )
                  else
                    Text(
                      'No Aadhaar document uploaded.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(
            title: 'Requested skills',
            subtitle: 'The worker\'s selected service categories and certifications.',
          ),
          const SizedBox(height: 12),
          if (profile.skills.isEmpty)
            const _SurfaceCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No skills were submitted with this profile.'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: profile.skills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final skill = profile.skills[index];
                return _SurfaceCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                skill.category?.name ?? 'Skill',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (skill.isPrimary)
                              _StatusChip(
                                label: 'Primary',
                                accent: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          skill.category?.description ?? skill.category?.slug ?? 'Category details unavailable',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Experience',
                          value: skill.yearsExperience?.toString() ?? 'Not provided',
                        ),
                        const SizedBox(height: 6),
                        _DetailRow(
                          label: 'Verified',
                          value: skill.verifiedByAdmin ? 'Yes' : 'No',
                        ),
                        const SizedBox(height: 6),
                        if (skill.hasCertificationDoc)
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      final url = await _api.fetchCertDocUrl(
                                          profile.id, skill.id);
                                      await _openUrl(url);
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  'Unable to open certification document.')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _busy = false);
                                    }
                                  },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Open certification'),
                          )
                        else
                          Text(
                            'No certification uploaded for this skill.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(
            title: 'Bank and payout details',
            subtitle: 'UPI is the primary payout route, with bank details as backup.',
          ),
          const SizedBox(height: 12),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'UPI ID', value: profile.upiId ?? 'Not provided'),
                  _DetailRow(label: 'Bank account', value: profile.bankAccountNumber ?? 'Not provided'),
                  _DetailRow(label: 'IFSC', value: profile.bankIfsc ?? 'Not provided'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (!isApproved) ...[
                        FilledButton.icon(
                          onPressed: _busy ? null : _approve,
                          icon: const Icon(Icons.verified_rounded),
                          label: const Text('Approve'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _reject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                        ),
                      ],
                      if (canSuspend)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _suspend,
                          icon: const Icon(Icons.pause_circle_outline_rounded),
                          label: const Text('Suspend'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'Not provided';
    }
    return MaterialLocalizations.of(context).formatMediumDate(value);
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

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
            width: 128,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({this.child});
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: child,
    );
  }
}
