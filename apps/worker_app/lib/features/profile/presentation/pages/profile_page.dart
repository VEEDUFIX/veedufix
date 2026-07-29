import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final user = auth?.user;

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
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () {},
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
                                user?.name ?? 'Guest worker',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Verified',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF10B981),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.role ?? 'WORKER',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: 0.9,
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
          // ── Performance Stats ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () => context.push('/reviews'),
                  child: const PremiumStatCard(
                    label: 'Rating',
                    value: '4.8',
                    icon: Icons.star_rounded,
                    accentColor: Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: PremiumStatCard(
                  label: 'Jobs Done',
                  value: '142',
                  icon: Icons.check_circle_rounded,
                  accentColor: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: PremiumStatCard(
                  label: 'Badges',
                  value: '4',
                  icon: Icons.military_tech_rounded,
                  accentColor: Color(0xFF8B5CF6),
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
          const _SectionCard(
            title: 'KYC status',
            subtitle: 'PAN verified, Aadhaar submitted, and background check approved.',
            icon: Icons.verified_user_rounded,
            accent: Color(0xFF10B981),
          ),
          const _SectionCard(
            title: 'Experience & skills',
            subtitle: '8 years experience · AC repair, electrical, plumbing, appliance setup.',
            icon: Icons.build_circle_rounded,
            accent: Color(0xFFC2A15E),
          ),
          const _SectionCard(
            title: 'Portfolio',
            subtitle: 'Upload your best completed jobs and before/after work images.',
            icon: Icons.collections_rounded,
            accent: Color(0xFF38BDF8),
          ),
          const _SectionCard(
            title: 'Bank details',
            subtitle: 'HDFC Bank · UPI payout enabled · weekly settlements active.',
            icon: Icons.account_balance_rounded,
            accent: Color(0xFFF59E0B),
          ),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Availability',
            subtitle: 'Control when you are visible to customers.',
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Weekly availability',
            subtitle: 'Set the hours you want to accept customer bookings.',
            icon: Icons.schedule_rounded,
            accent: const Color(0xFF14B8A6),
            onTap: () => context.push('/availability'),
          ),
          const _CompactLine(label: 'Working hours', value: '8:00 AM - 8:00 PM'),
          const _CompactLine(label: 'Online mode', value: 'Enabled'),
          const _CompactLine(label: 'Documents', value: '6 verified files'),
          const SizedBox(height: 18),
          const PremiumSectionHeader(
            title: 'Support',
            subtitle: 'Quick access to help, settings, and sign out.',
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.support_agent_rounded, 
            title: 'Support',
            onTap: () => context.push('/support'),
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
          _ActionTile(
            icon: Icons.logout_rounded, 
            title: 'Logout',
            onTap: () {
              // TODO: Wire to auth controller
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
              borderRadius: BorderRadius.circular(16),
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
              borderRadius: BorderRadius.circular(16),
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
