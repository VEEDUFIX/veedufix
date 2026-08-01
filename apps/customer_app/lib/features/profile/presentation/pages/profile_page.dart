import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

final customerAuthSessionsProvider = FutureProvider.autoDispose<List<CustomerAuthSession>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/auth/sessions');
  return (data['sessions'] as List<dynamic>? ?? [])
      .map((item) => CustomerAuthSession.fromJson(item as Map<String, dynamic>))
      .toList();
});

class CustomerAuthSession {
  const CustomerAuthSession({
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

  factory CustomerAuthSession.fromJson(Map<String, dynamic> json) => CustomerAuthSession(
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
    final user = ref.watch(authControllerProvider.select((s) => s.valueOrNull?.user));
    final completion = user == null ? 0.72 : 0.88;
    final unreadNotifications = ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;

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
                  onPressed: () => context.push('/settings'),
                  icon: const Icon(Icons.settings_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _initial(user?.name),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
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
                                user?.name ?? 'Guest',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.role ?? 'CUSTOMER',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: completion, minHeight: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _CompletionCard(value: completion),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Account',
            subtitle: 'Everything tied to your customer experience.',
          ),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: 'Saved addresses',
            subtitle: 'Home, work, and alternate locations',
            onTap: () => context.push('/addresses'),
          ),
          _ProfileTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Booking alerts and promotional offers',
            badgeCount: unreadNotifications,
            onTap: () => context.push('/notifications'),
          ),
          _ProfileTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'My Wallet',
            subtitle: 'View your credits, debits, and balance',
            onTap: () => context.push('/wallet'),
          ),
          _ProfileTile(
            icon: Icons.card_giftcard_rounded,
            title: 'Wallet & Referrals',
            subtitle: 'Credits, rewards, and referral code',
            onTap: () => context.push('/referral'),
          ),
          _ProfileTile(
            icon: Icons.payment_rounded,
            title: 'Payments',
            subtitle: 'Cards, UPI, and payment history',
            onTap: () => context.push('/wallet'),
          ),
          _ProfileTile(
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved services',
            subtitle: 'Repeat your most used bookings',
            onTap: () => context.push('/favorites'),
          ),
          _ProfileTile(
            icon: Icons.support_agent_rounded,
            title: 'Help & support',
            subtitle: 'Raise a query or track a request',
            onTap: () => context.push('/support'),
          ),
          _ProfileTile(
            icon: Icons.settings_rounded, 
            title: 'Settings', 
            subtitle: 'App preferences, notifications, and privacy',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Preferences',
            subtitle: 'Control how the experience feels and behaves.',
          ),
          const SizedBox(height: 12),
          const _PreferenceRow(label: 'Notifications', value: 'Enabled'),
          const _PreferenceRow(label: 'Language', value: 'English'),
          const _PreferenceRow(label: 'Theme', value: 'System'),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Security',
            subtitle: 'Review signed-in devices and end other sessions anytime.',
          ),
          const SizedBox(height: 12),
          _SecuritySessionsCard(
            onSignOutOthers: () => ref.read(apiClientProvider).delete('/auth/sessions'),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) {
      return 'U';
    }
    return name[0].toUpperCase();
  }
}

class _SecuritySessionsCard extends ConsumerWidget {
  const _SecuritySessionsCard({required this.onSignOutOthers});

  final Future<void> Function() onSignOutOthers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sessionsAsync = ref.watch(customerAuthSessionsProvider);

    return PremiumCard(
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
                      await onSignOutOthers();
                      ref.invalidate(customerAuthSessionsProvider);
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

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              ),
              child: Icon(
                Icons.insights_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile completion',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(value * 100).round()}% complete. Add more details to speed up future bookings.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeCount = 0,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int badgeCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TapScale(
        onTap: onTap ?? () {},
        child: PremiumCard(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
                  if (badgeCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
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
