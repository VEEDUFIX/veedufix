import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text(
          'Settings',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader(title: 'Preferences'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: 'English (US)',
            onTap: () => _showLanguagePicker(context),
          ),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Push, Email, SMS',
            onTap: () => _showNotificationPrefs(context),
          ),
          const SizedBox(height: 32),
          
          const _SectionHeader(title: 'Security & Privacy'),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy Center',
            subtitle: 'Manage your data and privacy',
            onTap: () => _showPrivacyCenter(context),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your data export request has been queued.')),
            ),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            isDestructive: true,
            onTap: () => _confirmDeleteAccount(context),
          ),
          const SizedBox(height: 32),

          const _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.description_rounded,
            title: 'Terms of Service',
            onTap: () => _showInfoDialog(
              context,
              title: 'Terms of Service',
              body: 'The worker app uses marketplace rules, payout policies, and service standards to keep the platform safe and reliable.',
            ),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () => _showInfoDialog(
              context,
              title: 'Privacy Policy',
              body: 'We only use your profile, job, and support data to operate the marketplace and improve your experience.',
            ),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'v1.0.0 (Build 42)',
            showChevron: false,
            onTap: () => _showInfoDialog(
              context,
              title: 'App Version',
              body: 'VeeduFix Partner v1.0.0 (Build 42)',
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: TapScale(
              onTap: () async {
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: Text(
                  'Log Out',
                  style: tt.titleMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDestructive = false,
    this.showChevron = true,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDestructive;
  final bool showChevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = isDestructive ? cs.error : cs.onSurface;

    return TapScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
          border: Border.all(
            color: isDestructive ? cs.error.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? cs.error.withValues(alpha: 0.1) : cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDestructive ? cs.error : cs.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

void _showInfoDialog(BuildContext context, {required String title, required String body}) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

void _showLanguagePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Choose language')),
          ListTile(
            title: const Text('English (US)'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language saved: English (US)')),
              );
            },
          ),
          ListTile(
            title: const Text('Hindi'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language saved: Hindi')),
              );
            },
          ),
          ListTile(
            title: const Text('Marathi'),
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language saved: Marathi')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

void _showNotificationPrefs(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Notification preferences'),
      content: const Text('Push, email, and SMS notifications are enabled by default for job updates and payouts.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
      ],
    ),
  );
}

void _showPrivacyCenter(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy Center'),
      content: const Text('You can export your data or request account deletion from this screen.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    ),
  );
}

void _confirmDeleteAccount(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text('This will queue a deletion request. You can still cancel by contacting support.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Deletion request submitted.')),
            );
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
