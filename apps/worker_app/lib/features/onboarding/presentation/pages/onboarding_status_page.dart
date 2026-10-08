import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/onboarding_provider.dart';

class OnboardingStatusPage extends ConsumerWidget {
  const OnboardingStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(workerOnboardingStatusProvider);

    return Scaffold(
      backgroundColor: VeeduFixDesignSystem.ivory,
      body: SafeArea(
        child: statusAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _OnboardingStatusShell(
                  title: 'Could not load your onboarding status',
                  subtitle: 'We could not load your onboarding profile right now.',
                  icon: Icons.info_outline_rounded,
                  extra: FilledButton.icon(
                    onPressed: () => ref.invalidate(workerOnboardingStatusProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ),
                data: (profile) {
                  if (profile == null) {
                    return const _OnboardingStatusShell(
                      title: 'Your application is not ready yet',
                      subtitle: 'We could not load your onboarding profile.',
                      icon: Icons.pending_actions_rounded,
                    );
                  }

                  final status = profile.onboardingStatus;
                  if (status == 'under_review') {
                    return _OnboardingStatusShell(
                      title: 'Your application is being reviewed',
                      subtitle:
                          'Thanks for submitting your details. We will notify you when the review is complete.',
                      icon: Icons.hourglass_top_rounded,
                      accent: VeeduFixDesignSystem.warning,
                      chips: const [
                        _StatusChip(icon: Icons.schedule_rounded, label: 'Review in progress'),
                        _StatusChip(icon: Icons.verified_user_outlined, label: 'Identity checked'),
                        _StatusChip(icon: Icons.support_agent_rounded, label: 'Support available'),
                      ],
                      extra: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What happens next',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'We are checking your personal details, identity document, and skill documents before approval.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (status == 'rejected') {
                    final suggestedStep = _stepForReason(profile.rejectionReason);
                    return _OnboardingStatusShell(
                      title: 'Your application needs a few fixes',
                      subtitle: profile.rejectionReason ?? 'Please review the feedback and resubmit your details.',
                      icon: Icons.warning_amber_rounded,
                      accent: VeeduFixDesignSystem.error,
                      chips: const [
                        _StatusChip(icon: Icons.edit_note_rounded, label: 'Can be updated'),
                        _StatusChip(icon: Icons.verified_user_outlined, label: 'Feedback provided'),
                      ],
                      extra: PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Review feedback',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                profile.rejectionReason ?? 'Your submission was not approved yet.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              PrimaryActionButton(
                                label: 'Fix and Resubmit',
                                onPressed: () {
                                  context.go('/onboarding?mode=edit&step=$suggestedStep');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  if (status == 'suspended') {
                    return const _OnboardingStatusShell(
                      title: 'Your account is currently suspended',
                      subtitle: 'Please contact support to continue using the worker app.',
                      icon: Icons.pause_circle_outline_rounded,
                      accent: VeeduFixDesignSystem.mutedInk,
                      chips: [
                        _StatusChip(icon: Icons.headset_mic_rounded, label: 'Contact support'),
                        _StatusChip(icon: Icons.lock_outline_rounded, label: 'Account paused'),
                      ],
                    );
                  }

                  return const _OnboardingStatusShell(
                    title: 'Your onboarding is in progress',
                    subtitle: 'Please continue setting up your profile to get approved.',
                    icon: Icons.person_search_rounded,
                    accent: VeeduFixDesignSystem.gold,
                    chips: [
                      _StatusChip(icon: Icons.save_outlined, label: 'Draft saved'),
                      _StatusChip(icon: Icons.badge_rounded, label: 'Profile incomplete'),
                    ],
                  );
                },
        ),
      ),
    );
  }

  int _stepForReason(String? reason) {
    final text = reason?.toLowerCase() ?? '';
    if (text.contains('aadhaar') || text.contains('identity') || text.contains('document')) {
      return 5;
    }
    if (text.contains('experience') || text.contains('qualification')) {
      return 3;
    }
    if (text.contains('skill') || text.contains('service')) {
      return 2;
    }
    if (text.contains('upi') || text.contains('bank')) {
      return 7;
    }
    if (text.contains('area') || text.contains('pincode') || text.contains('availability')) {
      return 4;
    }
    if (text.contains('agreement') || text.contains('consent') || text.contains('safety')) {
      return 10;
    }
    return 1;
  }
}

class _OnboardingStatusShell extends StatelessWidget {
  const _OnboardingStatusShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accent = VeeduFixDesignSystem.gold,
    this.chips = const <Widget>[],
    this.extra,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<Widget> chips;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        PremiumGlassCard(
          child: Padding(
            padding: const EdgeInsets.all(VeeduFixDesignSystem.space20),
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
                        borderRadius: BorderRadius.circular(
                          VeeduFixDesignSystem.radiusLarge,
                        ),
                      ),
                      child: Icon(icon, size: 34, color: accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Worker onboarding',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  letterSpacing: 0.4,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: chips,
                  ),
                ],
                if (extra != null) ...[
                  const SizedBox(height: 18),
                  extra!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

