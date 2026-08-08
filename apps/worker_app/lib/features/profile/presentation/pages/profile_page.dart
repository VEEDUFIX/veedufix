import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/worker_profile_providers.dart';

final workerAuthSessionsProvider = FutureProvider.autoDispose<List<WorkerAuthSession>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/auth/sessions');
  return (data['sessions'] as List<dynamic>? ?? [])
      .map((item) => WorkerAuthSession.fromJson(item as Map<String, dynamic>))
      .toList();
});

class WorkerAuthSession {
  const WorkerAuthSession({
    required this.id,
    required this.provider,
    required this.createdAt,
    required this.updatedAt,
    required this.isCurrent,
    required this.isActive,
  });

  final String id;
  final String provider;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCurrent;
  final bool isActive;

  factory WorkerAuthSession.fromJson(Map<String, dynamic> json) => WorkerAuthSession(
        id: json['id'] as String? ?? '',
        provider: json['provider'] as String? ?? 'PHONE',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        isCurrent: json['isCurrent'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? false,
      );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final accountAsync = ref.watch(workerAccountProfileProvider);

    return accountAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Failed to load profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.refresh(workerAccountProfileProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (account) {
        final userMap = (account['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final workerProfile = (userMap['workerProfile'] as Map<String, dynamic>?) ?? <String, dynamic>{};

        return _ProfileContent(
          sessionUser: session?.user,
          userMap: userMap,
          workerProfile: workerProfile,
        );
      },
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({
    required this.sessionUser,
    required this.userMap,
    required this.workerProfile,
  });

  final AuthUser? sessionUser;
  final Map<String, dynamic> userMap;
  final Map<String, dynamic> workerProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = _nonEmpty(workerProfile['displayName']) ??
        _nonEmpty(workerProfile['fullName']) ??
        _nonEmpty(userMap['name']) ??
        sessionUser?.name ??
        'Guest worker';
    final avatarUrl = _nonEmpty(userMap['avatarUrl']) ?? sessionUser?.avatarUrl;
    final verificationStatus = _nonEmpty(workerProfile['verificationStatus']) ?? 'PENDING';
    final averageRating = _doubleValue(workerProfile['averageRating']);
    final completedJobsCount = _intValue(workerProfile['completedJobsCount']);
    final experienceYears = _intValue(workerProfile['experienceYears']);
    final isAvailable = workerProfile['isAvailable'] as bool? ?? false;
    final bio = _nonEmpty(workerProfile['bio']);
    final skills = _skillNames(workerProfile['skills']);
    final progress = _profileProgress(
      name: userName,
      bio: bio,
      skills: skills,
      verificationStatus: verificationStatus,
    );
    final bankDetails = _bankSummary(workerProfile);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                ),
              ),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: IconButton(
                  onPressed: () => context.push('/profile/edit'),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: IconButton(
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: avatarUrl == null
                        ? Text(
                            _initial(userName),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : ClipOval(
                            child: MarketplaceNetworkAvatar(
                              imageUrl: avatarUrl,
                              radius: 32,
                              fallback: Text(
                                _initial(userName),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: verificationStatus == 'VERIFIED'
                                    ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _friendlyVerificationLabel(verificationStatus),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: verificationStatus == 'VERIFIED'
                                          ? const Color(0xFF10B981)
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sessionUser?.role ?? 'WORKER',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () => context.push('/reviews'),
                  child: PremiumStatCard(
                    label: 'Rating',
                    value: averageRating.toStringAsFixed(1),
                    icon: Icons.star_rounded,
                    accentColor: const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Jobs Done',
                  value: completedJobsCount.toString(),
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Experience',
                  value: '${experienceYears}y',
                  icon: Icons.military_tech_rounded,
                  accentColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Work profile',
            subtitle: 'Manage identity, availability, and service credentials.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'KYC status',
            subtitle: _friendlyVerificationLabel(verificationStatus),
            icon: Icons.verified_user_rounded,
            accent: const Color(0xFF10B981),
            onTap: () => context.push('/documents/upload'),
          ),
          _SectionCard(
            title: 'Experience & skills',
            subtitle: _experienceSummary(experienceYears, bio, skills),
            icon: Icons.build_circle_rounded,
            accent: const Color(0xFFC2A15E),
          ),
          const _SectionCard(
            title: 'Portfolio',
            subtitle: 'Upload your best completed jobs and before/after work images.',
            icon: Icons.collections_rounded,
            accent: Color(0xFF38BDF8),
          ),
          _SectionCard(
            title: 'Bank details',
            subtitle: bankDetails,
            icon: Icons.account_balance_rounded,
            accent: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Availability',
            subtitle: 'Control when you are visible to customers.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Weekly availability',
            subtitle: isAvailable
                ? 'You are currently visible to customers.'
                : 'Turn on availability to receive customer bookings.',
            icon: Icons.schedule_rounded,
            accent: const Color(0xFF14B8A6),
            onTap: () => context.push('/availability'),
          ),
          _CompactLine(label: 'Verification', value: _friendlyVerificationLabel(verificationStatus)),
          _CompactLine(label: 'Availability', value: isAvailable ? 'Enabled' : 'Paused'),
          _CompactLine(label: 'Skills', value: skills.isEmpty ? 'None yet' : skills.length.toString()),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Support',
            subtitle: 'Quick access to help, settings, and sign out.',
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            onTap: () => context.push(
              '/support?autoFocusForm=true&category=app&subject=${Uri.encodeComponent('Worker support request')}&message=${Uri.encodeComponent('I need help with my worker account, jobs, payouts, or app experience.')}',
            ),
          ),
          _ActionTile(
            icon: Icons.star_rounded,
            title: 'Reviews & Ratings',
            onTap: () => context.push('/reviews'),
          ),
          _ActionTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Security',
            subtitle: 'Review signed-in devices and end other sessions anytime.',
          ),
          const SizedBox(height: 12),
          const _WorkerSecuritySessionsCard(),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            onTap: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) {
      return 'W';
    }
    return name[0].toUpperCase();
  }

  static double _profileProgress({
    required String name,
    required String? bio,
    required List<String> skills,
    required String verificationStatus,
  }) {
    var progress = 0.0;
    if (name.trim().isNotEmpty) progress += 0.25;
    if (bio != null && bio.trim().isNotEmpty) progress += 0.25;
    if (skills.isNotEmpty) progress += 0.25;
    if (verificationStatus == 'VERIFIED') progress += 0.25;
    return progress.clamp(0.0, 1.0);
  }

  static String _experienceSummary(int years, String? bio, List<String> skills) {
    final skillText = skills.isEmpty ? 'Add your specialties in edit profile.' : skills.take(3).join(', ');
    return '$years years experience · $skillText';
  }

  static String _friendlyVerificationLabel(String status) {
    switch (status.toUpperCase()) {
      case 'VERIFIED':
        return 'Verified';
      case 'REJECTED':
        return 'Rejected';
      case 'SUSPENDED':
        return 'Suspended';
      case 'PENDING':
      default:
        return 'Pending review';
    }
  }

  static String _bankSummary(Map<String, dynamic> profile) {
    final parts = <String>[];
    final bankAccount = _nonEmpty(profile['bankAccountNumber']);
    final bankIfsc = _nonEmpty(profile['bankIfsc']);
    final upiId = _nonEmpty(profile['upiId']);

    if (bankAccount != null) {
      parts.add('Account $bankAccount');
    }
    if (bankIfsc != null) {
      parts.add('IFSC $bankIfsc');
    }
    if (upiId != null) {
      parts.add('UPI $upiId');
    }

    if (parts.isEmpty) {
      return 'Add bank or UPI details for payouts.';
    }

    return parts.join(' · ');
  }
}

class _WorkerSecuritySessionsCard extends ConsumerWidget {
  const _WorkerSecuritySessionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sessionsAsync = ref.watch(workerAuthSessionsProvider);

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: sessionsAsync.when(
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(),
          )),
          error: (error, _) => Text('Could not load sessions: $error'),
          data: (sessions) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.devices_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Signed-in devices', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await ref.read(apiClientProvider).delete('/auth/sessions');
                      ref.invalidate(workerAuthSessionsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Other sessions signed out')),
                        );
                      }
                    },
                    child: const Text('Sign out others'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                Text('No active sessions found.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
              else
                Column(
                  children: sessions.map((session) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(session.isCurrent ? Icons.smartphone_rounded : Icons.devices_other_rounded, size: 18, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.provider.toUpperCase(),
                                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Last active ${DateFormat('d MMM, h:mm a').format(session.updatedAt)}',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            if (session.isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: cs.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Current', style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Icon(icon, color: accent),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          trailing: Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TapScale(
        onTap: onTap ?? () {},
        child: PremiumGlassCard(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

String? _nonEmpty(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return 0.0;
}

List<String> _skillNames(dynamic rawSkills) {
  if (rawSkills is! List) {
    return const [];
  }

  return rawSkills
      .whereType<Map>()
      .map((skill) {
        final category = skill['category'];
        if (category is Map) {
          final name = category['name'];
          if (name is String && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
        final fallback = skill['categoryName'];
        if (fallback is String && fallback.trim().isNotEmpty) {
          return fallback.trim();
        }
        return null;
      })
      .whereType<String>()
      .toList(growable: false);
}
