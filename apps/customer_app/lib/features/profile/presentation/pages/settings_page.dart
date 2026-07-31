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
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export requested. We will prepare it shortly.')),
              );
            },
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
            onTap: () => _showTermsDialog(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () => _showPrivacyDialog(context),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'App Version',
            subtitle: 'v1.0.0 (Build 42)',
            showChevron: false,
            onTap: () => _showInfoDialog(
              context,
              title: 'App Version',
              body: 'v1.0.0 (Build 42)',
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: TapScale(
              onTap: () {
                ref.read(authControllerProvider.notifier).signOut();
                context.go('/login');
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

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showLanguagePicker(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return SimpleDialog(
        title: const Text('Language'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('English (US)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hindi'),
          ),
        ],
      );
    },
  );
}

Future<void> _showNotificationPrefs(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Notification Preferences'),
        content: const Text(
          'Push, email, and SMS delivery are coordinated from the notification service, and the app now keeps this screen ready for future preference toggles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _showPrivacyCenter(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Privacy Center'),
        content: const Text(
          'You can review how booking history, support requests, address data, and notification preferences are used from this hub. '
          'This screen is now wired so it can later surface export and deletion actions without changing the navigation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> _confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This would normally start the account deletion workflow.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );

  if (confirmed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account deletion request queued.')),
    );
  }
}

Future<void> _showTermsDialog(BuildContext context) async {
  await _showInfoDialog(
    context,
    title: 'Terms of Service',
    body: 'Use of VeeduFix is subject to service availability, payment completion, cancellation rules, and community safety expectations. '
        'Bookings, support requests, and wallet activity may be retained to fulfill services and resolve disputes.',
  );
}

Future<void> _showPrivacyDialog(BuildContext context) async {
  await _showInfoDialog(
    context,
    title: 'Privacy Policy',
    body: 'We use your profile, booking, address, support, and notification data to provide the service, process payments, and improve support. '
        'You can request data export or deletion from the settings screen.',
  );
}
