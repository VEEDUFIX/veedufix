import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/notifications/worker_device_token.dart';

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
          appText(context, 'Settings', 'அமைப்புகள்'),
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _SectionHeader(title: appText(context, 'Preferences', 'விருப்பங்கள்')),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: appLanguageName(ref.watch(appLocaleProvider)),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: appText(context, 'Notifications', 'அறிவிப்புகள்'),
            subtitle: 'Manage alerts for jobs and payouts',
            onTap: () => _showNotificationPrefs(context, ref),
          ),
          _SettingsTile(
            icon: Icons.network_check_rounded,
            title: 'Connection diagnostics',
            subtitle: 'Check the app and service connection',
            onTap: () => context.push('/connection-diagnostics'),
          ),
          const SizedBox(height: 32),
          
          _SectionHeader(title: appText(context, 'Security & Privacy', 'பாதுகாப்பு மற்றும் தனியுரிமை')),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy Center',
            subtitle: 'Request a data copy or account deletion',
            onTap: () => _openSupportRequest(
              context,
              subject: 'Privacy and data request',
              message: 'Please help me with a privacy or personal data request for my Veedufix Partner account.',
            ),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            subtitle: 'Copy your account data as JSON',
            onTap: () => _exportWorkerData(context, ref),
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
              body: 'For a copy or deletion request for your account data, contact Veedufix Support so the team can verify your identity and explain any requirements.',
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
              onTap: () => _confirmSignOut(context, ref),
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

Future<void> _exportWorkerData(BuildContext context, WidgetRef ref) async {
  try {
    final data = await ref.read(apiClientProvider).get('/users/me/data-export');
    final json = const JsonEncoder.withIndent('  ').convert(data);
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your account export was copied as JSON. Store it securely.'),
      ));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export your data: $error')),
      );
    }
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

Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final activeLanguage = ref.read(appLocaleProvider).languageCode;
      return SimpleDialog(
        title: Text(appText(context, 'Choose language', 'மொழியைத் தேர்ந்தெடுக்கவும்')),
        children: [
          for (final option in const [('en', 'English'), ('ta', 'தமிழ்')])
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(option.$1),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.$2),
                trailing: activeLanguage == option.$1
                    ? const Icon(Icons.check_rounded)
                    : null,
              ),
            ),
        ],
      );
    },
  );
  if (selected == null || !context.mounted) return;
  try {
    await ref.read(appLocaleProvider.notifier).setLanguage(selected);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appText(context, 'Could not save language preference.', 'மொழி விருப்பத்தைச் சேமிக்க முடியவில்லை.'))),
    );
  }
}

Future<void> _showNotificationPrefs(BuildContext context, WidgetRef ref) async {
  var marketingEnabled = false;
  String? errorMessage;
  try {
    final preferences = await ref
        .read(apiClientProvider)
        .get('/users/me/notification-preferences');
    marketingEnabled = preferences['marketingNotificationsEnabled'] == true;
  } catch (_) {
    errorMessage = 'Could not load your saved notification preference.';
  }
  if (!context.mounted) return;
  var isSaving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Notification preferences'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job and payout alerts follow your device notification permission.'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offers and promotions'),
              subtitle: const Text('Receive promotional messages on your account'),
              value: marketingEnabled,
              onChanged: isSaving
                  ? null
                  : (value) async {
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });
                      try {
                        final updated = await ref.read(apiClientProvider).patch(
                          '/users/me/notification-preferences',
                          data: {'marketingNotificationsEnabled': value},
                        );
                        if (!context.mounted) return;
                        setDialogState(() {
                          marketingEnabled = updated['marketingNotificationsEnabled'] == true;
                        });
                      } catch (_) {
                        if (context.mounted) {
                          setDialogState(() => errorMessage = 'Could not save this preference. Try again.');
                        }
                      } finally {
                        if (context.mounted) setDialogState(() => isSaving = false);
                      }
                    },
            ),
            if (isSaving) const LinearProgressIndicator(),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

void _confirmDeleteAccount(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text('Account deletion is handled by support after your identity and any active jobs or payouts are reviewed. Continue to contact support?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _openSupportRequest(
              context,
              subject: 'Request to delete my account',
              message: 'Please explain the steps to delete my Veedufix Partner account.',
            );
          },
          child: const Text('Contact support'),
        ),
      ],
    ),
  );
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final shouldSignOut = await showDialog<bool>(
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
  if (shouldSignOut != true || !context.mounted) return;
  await unregisterWorkerDeviceToken(ref.read(apiClientProvider));
  await ref.read(authControllerProvider.notifier).signOut();
  if (context.mounted) context.go('/login');
}

void _openSupportRequest(
  BuildContext context, {
  required String subject,
  required String message,
}) {
  context.push(
    '/support?autoFocusForm=true&category=account&subject=${Uri.encodeComponent(subject)}&message=${Uri.encodeComponent(message)}',
  );
}
