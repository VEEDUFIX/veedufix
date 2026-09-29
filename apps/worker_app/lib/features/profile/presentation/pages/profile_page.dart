import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/notifications/worker_device_token.dart';
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
    final experienceYears = _intValue(workerProfile['experienceYears']) > 0
        ? _intValue(workerProfile['experienceYears'])
        : _experienceFromTools(workerProfile['toolsOwned']);
    final isAvailable = workerProfile['isAvailable'] as bool? ?? false;
    final bio = _nonEmpty(workerProfile['bio']);
    final skills = _skillNames(workerProfile['skills']);
    final primaryService = skills.isEmpty ? 'No primary service selected' : skills.first;
    final serviceArea = _serviceAreaSummary(workerProfile);
    final hasProfessionalDocument = _hasProfessionalDocument(workerProfile);
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
                        'PARTNER',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 5,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${(progress * 100).round()}% complete',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: [
              TapScale(
                onTap: () => context.push('/reviews'),
                child: PremiumStatCard(label: 'Rating', value: averageRating.toStringAsFixed(1), icon: Icons.star_rounded, accentColor: const Color(0xFFF59E0B)),
              ),
              PremiumStatCard(label: 'Jobs completed', value: completedJobsCount.toString(), icon: Icons.check_circle_rounded, accentColor: const Color(0xFF10B981)),
              PremiumStatCard(label: 'Experience', value: '${experienceYears}y', icon: Icons.military_tech_rounded, accentColor: const Color(0xFFC2A15E)),
            ],
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Work profile',
            subtitle: 'Manage your identity, services, and professional credentials.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'KYC & verification',
            subtitle: _friendlyVerificationLabel(verificationStatus),
            icon: Icons.verified_user_rounded,
            accent: const Color(0xFF10B981),
            onTap: () => context.push('/profile/kyc'),
          ),
          _SectionCard(
            title: 'Experience & skills',
            subtitle: '$experienceYears years • $primaryService • ${skills.length} skills',
            icon: Icons.build_circle_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/experience'),
          ),
          _SectionCard(
            title: 'Services',
            subtitle: skills.isEmpty ? 'Add the services you provide.' : skills.take(3).join(', '),
            icon: Icons.home_repair_service_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/services'),
          ),
          _SectionCard(
            title: 'Portfolio',
            subtitle: 'Add completed-work and before/after photos.',
            icon: Icons.collections_rounded,
            accent: const Color(0xFF38BDF8),
            onTap: () => context.push('/profile/portfolio'),
          ),
          const SizedBox(height: 12),
          const PremiumSectionHeader(
            title: 'Service area',
            subtitle: 'Manage where customers can book you.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Service area',
            subtitle: serviceArea,
            icon: Icons.location_on_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/service-area'),
          ),
          const SizedBox(height: 6),
          const PremiumSectionHeader(
            title: 'Professional documents',
            subtitle: 'Keep certificates and licenses up to date.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Professional documents',
            subtitle: hasProfessionalDocument ? 'Documents uploaded • Review or replace' : 'No additional documents required',
            icon: Icons.badge_rounded,
            accent: hasProfessionalDocument ? const Color(0xFF16A34A) : const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/documents'),
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
                ? 'Available for bookings • ${_availabilitySummary(workerProfile)}'
                : 'Turn on availability to receive customer bookings.',
            icon: Icons.schedule_rounded,
            accent: const Color(0xFF14B8A6),
            onTap: () => context.push('/availability'),
          ),
          _SectionCard(
            title: 'Service preferences',
            subtitle: '${_urgentJobsLabel(workerProfile)} • ${workerProfile['workType'] == 'PART_TIME' ? 'Part-time preference' : 'Full-time preference'}',
            icon: Icons.tune_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/availability'),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Payments',
            subtitle: 'Manage payout information securely.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Bank details',
            subtitle: bankDetails,
            icon: Icons.account_balance_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/bank-details'),
          ),
          _SectionCard(
            title: 'Payment details',
            subtitle: 'Payout information and verification status',
            icon: Icons.payments_rounded,
            accent: const Color(0xFFC2A15E),
            onTap: () => context.push('/profile/payment-details'),
          ),
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
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Account status',
            subtitle: 'A quick view of your partner account.',
          ),
          const SizedBox(height: 12),
          _AccountStatusCard(
            identityVerified: verificationStatus == 'VERIFIED',
            servicesActive: skills.isNotEmpty,
            paymentsAdded: bankDetails != 'Add bank or UPI details for payouts.',
            profileComplete: progress >= 0.75,
          ),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out of Veedufix?'),
                  content: const Text('You can sign in again anytime using your registered mobile number.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Log out')),
                  ],
                ),
              );
              if (shouldLogout != true) return;
              await unregisterWorkerDeviceToken(ref.read(apiClientProvider));
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

  static String _serviceAreaSummary(Map<String, dynamic> profile) {
    final city = _nonEmpty(profile['city']) ?? _nonEmpty(profile['addressLine1']) ?? 'Add your city';
    final areas = _nonEmpty(profile['serviceAreas']);
    final pincode = _nonEmpty(profile['pincode']);
    final travel = profile['serviceRadiusKm']?.toString();
    return [
      city,
      if (areas != null) areas,
      if (pincode != null) 'Pincode $pincode',
      if (travel != null) 'Up to $travel km',
    ].join(' • ');
  }

  static String _availabilitySummary(Map<String, dynamic> profile) {
    final slots = profile['availabilitySlots'];
    if (slots is List && slots.isNotEmpty) {
      final daySlots = slots.whereType<Map<String, dynamic>>().toList(growable: false);
      final days = daySlots
          .map((slot) => slot['dayOfWeek'])
          .whereType<num>()
          .map((day) => day.toInt())
          .toSet()
          .length;
      if (daySlots.isEmpty) return 'Working days set';
      final first = daySlots.first;
      final start = first['startTime']?.toString();
      final end = first['endTime']?.toString();
      final hours = start != null && end != null ? ' • $start–$end' : '';
      return '$days working days set$hours';
    }
    return 'Set working days and hours';
  }

  static int _experienceFromTools(dynamic value) {
    if (value is! List) return 0;
    final years = value
        .whereType<String>()
        .map((summary) => RegExp(r'(\d+) years').firstMatch(summary))
        .whereType<RegExpMatch>()
        .map((match) => int.tryParse(match.group(1) ?? '0') ?? 0)
        .toList(growable: false);
    return years.isEmpty ? 0 : years.reduce((left, right) => left > right ? left : right);
  }

  static String _urgentJobsLabel(Map<String, dynamic> profile) {
    return profile['acceptsUrgentJobs'] == true ? 'Emergency jobs on' : 'Emergency jobs off';
  }

  static bool _hasProfessionalDocument(Map<String, dynamic> profile) {
    final skills = profile['skills'];
    return skills is List && skills.any((skill) => skill is Map && skill['hasCertificationDoc'] == true);
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
      final suffix = bankAccount.length > 4
          ? bankAccount.substring(bankAccount.length - 4)
          : bankAccount;
      parts.add('Account ending ••••$suffix');
    }
    if (bankIfsc != null) {
      parts.add('IFSC ••••••••');
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

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({
    required this.identityVerified,
    required this.servicesActive,
    required this.paymentsAdded,
    required this.profileComplete,
  });

  final bool identityVerified;
  final bool servicesActive;
  final bool paymentsAdded;
  final bool profileComplete;

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, bool>>[
      MapEntry('Identity verified', identityVerified),
      MapEntry('Services active', servicesActive),
      MapEntry('Payment details added', paymentsAdded),
      MapEntry('Profile complete', profileComplete),
    ];
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Icon(
                        item.value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: item.value ? const Color(0xFF16A34A) : const Color(0xFF9A9287),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item.key)),
                      if (!item.value)
                        const Text('Action required', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A9287))),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
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
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Sign out other devices?'),
                          content: const Text('Other devices will need to sign in again. This device will stay signed in.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sign out others')),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref.read(apiClientProvider).delete('/auth/sessions');
                        ref.invalidate(workerAuthSessionsProvider);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not sign out other devices: $error')));
                        }
                        return;
                      }
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
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  leading: Icon(Icons.smartphone_rounded, color: cs.primary),
                  title: Text(
                    'Current device',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${sessions.firstWhere((session) => session.isCurrent, orElse: () => sessions.first).provider.toUpperCase()} • Last active just now',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
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
                                  Text(session.provider.toUpperCase(), style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  Text('Last active ${DateFormat('d MMM, h:mm a').format(session.updatedAt)}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            if (session.isCurrent)
                              Text('Current', style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    );
                  }).toList(growable: false),
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
