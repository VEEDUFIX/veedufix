import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/notifications/customer_device_token.dart';

final customerAuthSessionsProvider =
    FutureProvider.autoDispose<List<CustomerAuthSession>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final data = await api.get('/auth/sessions');
      return (data['sessions'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                CustomerAuthSession.fromJson(item as Map<String, dynamic>),
          )
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

  factory CustomerAuthSession.fromJson(
    Map<String, dynamic> json,
  ) => CustomerAuthSession(
    id: json['id'] as String? ?? '',
    provider: json['provider'] as String? ?? 'PHONE',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    isCurrent: json['isCurrent'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? false,
  );
}

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.user),
    );
    final unreadNotifications =
        ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;

    if (user == null) {
      return const _GuestProfileSignIn();
    }
    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          VeeduFixDesignSystem.pageMargin,
          MediaQuery.paddingOf(context).top + 16,
          VeeduFixDesignSystem.pageMargin,
          24,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Account',
                  style: Theme.of(context).textTheme.headlineMedium,
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
          _ProfileHeroCard(user: user),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Account',
            subtitle: 'Everything tied to your customer experience.',
          ),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.location_on_rounded,
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
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved services',
            subtitle: 'Repeat your most used bookings',
            onTap: () => context.push('/favorites'),
          ),
          _ProfileTile(
            icon: Icons.support_agent_rounded,
            title: 'Help & support',
            subtitle: 'Raise a query or track a request',
            onTap: () => context.push(
              '/support?autoCompose=true&category=other&subject=${Uri.encodeComponent('Account support')}&message=${Uri.encodeComponent('I need help with my account or app experience.')}',
            ),
          ),
          _ProfileTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'App preferences, notifications, and privacy',
            onTap: () => context.push('/settings'),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Rewards',
            subtitle: 'Credits, referrals, and offers for repeat bookings.',
          ),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.card_giftcard_rounded,
            title: 'Refer a friend',
            subtitle: 'Share your code and earn referral rewards',
            onTap: () => context.push('/referral'),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Security',
            subtitle:
                'Review signed-in devices and end other sessions anytime.',
          ),
          const SizedBox(height: 12),
          _SecuritySessionsCard(
            onSignOutOthers: () =>
                ref.read(apiClientProvider).delete('/auth/sessions'),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _confirmCustomerSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.45),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
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
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, __) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not load signed-in devices.'),
              TextButton.icon(
                onPressed: () => ref.invalidate(customerAuthSessionsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
          data: (sessions) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.devices_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Signed-in devices',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        sessions.any(
                          (session) => !session.isCurrent && session.isActive,
                        )
                        ? () => _confirmSignOutOthers(context, ref)
                        : null,
                    child: const Text('Sign out others'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sessions.isEmpty)
                Text(
                  'No active sessions found.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                )
              else
                Column(
                  children: sessions.map((session) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              session.isCurrent
                                  ? Icons.smartphone_rounded
                                  : Icons.devices_other_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.provider.toUpperCase(),
                                    style: tt.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Last active ${DateFormat('d MMM, h:mm a').format(session.updatedAt)}',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _SessionStatusPill(
                              label: session.isCurrent
                                  ? 'Current'
                                  : session.isActive
                                  ? 'Active'
                                  : 'Signed out',
                              color: session.isCurrent
                                  ? cs.primary
                                  : session.isActive
                                  ? cs.tertiary
                                  : cs.onSurfaceVariant,
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

  Future<void> _confirmSignOutOthers(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out other devices?'),
        content: const Text(
          'Other devices will need to sign in again to use your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await onSignOutOthers();
      ref.invalidate(customerAuthSessionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Other sessions signed out')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sign out other devices. Try again.'),
          ),
        );
      }
    }
  }
}

class _SessionStatusPill extends StatelessWidget {
  const _SessionStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GuestProfileSignIn extends StatelessWidget {
  const _GuestProfileSignIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(VeeduFixDesignSystem.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: VeeduFixDesignSystem.ink,
                  borderRadius: BorderRadius.circular(
                    VeeduFixDesignSystem.radiusLarge,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AbzioTheme.accentColor,
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to manage your account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'View bookings, saved addresses, wallet credits, referrals, and support in one place.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              VeeduFixButton(
                onPressed: () => context.go('/login'),
                label: 'Sign in',
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/app'),
                child: const Text('Continue browsing'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final phone = user.phone?.trim();
    final text = Theme.of(context).textTheme;
    return VeeduFixCard(
      child: Row(
        children: [
          MarketplaceNetworkAvatar(
            imageUrl: user.avatarUrl,
            radius: 32,
            backgroundColor: AbzioTheme.lightMuted,
            fallback: Text(
              _initial(user.name),
              style: text.titleLarge?.copyWith(
                color: AbzioTheme.lightTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name.trim().isEmpty
                            ? 'Customer'
                            : user.name.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phone?.isNotEmpty == true
                      ? phone!
                      : 'Phone verified customer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'U';
    }
    return name.trim()[0].toUpperCase();
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
      child: PremiumCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
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
    );
  }
}

Future<void> _confirmCustomerSignOut(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out of Veedufix?'),
      content: const Text(
        'You can sign in again anytime using your registered mobile number.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await unregisterCustomerDeviceToken(ref.read(apiClientProvider));
  } catch (_) {
    // Signing out must remain possible when push-token cleanup is unavailable.
  }

  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {
    // Backend/local sign-out still clears the app session if Firebase is offline.
  }
  try {
    await ref.read(authControllerProvider.notifier).signOut();
  } catch (_) {
    // Navigation should still leave the profile when remote/local cleanup fails.
  }
  if (context.mounted) context.go('/login');
}
