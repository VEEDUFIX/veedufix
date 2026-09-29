import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/notifications/customer_device_token.dart';

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
          _SectionHeader(
            title: appText(context, 'Preferences', 'விருப்பங்கள்'),
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: appText(context, 'Language', 'மொழி'),
            subtitle: appLanguageName(ref.watch(appLocaleProvider)),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            title: appText(context, 'Notifications', 'அறிவிப்புகள்'),
            subtitle: 'Push notifications on this device',
            onTap: () => _showNotificationPrefs(context, ref),
          ),
          const SizedBox(height: 32),
          _SectionHeader(
            title: appText(
              context,
              'Security & Privacy',
              'பாதுகாப்பு மற்றும் தனியுரிமை',
            ),
          ),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Privacy Center',
            subtitle: 'Manage your data and privacy',
            onTap: () => _openSupportRequest(
              context,
              category: 'privacy',
              subject: 'Privacy and data question',
              message: 'I have a question about my personal data or privacy.',
            ),
          ),
          _SettingsTile(
            icon: Icons.download_rounded,
            title: 'Export My Data',
            onTap: () => _openSupportRequest(
              context,
              category: 'privacy',
              subject: 'Request a copy of my data',
              message:
                  'Please help me request a copy of the personal data associated with my Veedufix account.',
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
            onTap: () => _openLegalPage(context, 'https://veedufix.com/terms'),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            onTap: () =>
                _openLegalPage(context, 'https://veedufix.com/privacy'),
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
              onTap: () async {
                await unregisterCustomerDeviceToken(
                  ref.read(apiClientProvider),
                );
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {
                  // Clear the backend session even if Firebase is unavailable.
                }
                await ref.read(authControllerProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
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
            color: isDestructive
                ? cs.error.withValues(alpha: 0.3)
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive
                    ? cs.error.withValues(alpha: 0.1)
                    : cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDestructive ? cs.error : cs.primary,
                size: 22,
              ),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
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

Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final activeLanguage = ref.read(appLocaleProvider).languageCode;
      return SimpleDialog(
        title: Text(
          appText(context, 'Choose language', 'மொழியைத் தேர்ந்தெடுக்கவும்'),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('en'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('English'),
              trailing: activeLanguage == 'en'
                  ? const Icon(Icons.check_rounded)
                  : null,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop('ta'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('தமிழ்'),
              trailing: activeLanguage == 'ta'
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              'Could not save language preference.',
              'மொழி விருப்பத்தைச் சேமிக்க முடியவில்லை.',
            ),
          ),
        ),
      );
    }
  }
}

Future<void> _showNotificationPrefs(BuildContext context, WidgetRef ref) async {
  final hasFirebaseConfig = ref.read(environmentProvider).hasFirebaseConfig;
  var enabled = false;
  if (hasFirebaseConfig) {
    try {
      enabled = await customerPushNotificationsEnabled();
    } catch (_) {
      enabled = false;
    }
  }
  if (!context.mounted) return;
  var isSaving = false;
  String? errorMessage;

  Future<void> updatePreference(
    bool value,
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    if (!dialogContext.mounted) return;
    setDialogState(() {
      isSaving = true;
      errorMessage = null;
    });
    try {
      final updated = await updateCustomerPushNotifications(
        ref.read(apiClientProvider),
        enabled: value,
      );
      if (!dialogContext.mounted) return;
      setDialogState(() {
        if (updated) {
          enabled = value;
        } else {
          errorMessage =
              'Allow notifications in your device settings to turn them on.';
        }
      });
    } catch (_) {
      if (dialogContext.mounted) {
        setDialogState(
          () => errorMessage = 'Could not update this preference. Try again.',
        );
      }
    } finally {
      if (dialogContext.mounted) {
        setDialogState(() => isSaving = false);
      }
    }
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Push notifications'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasFirebaseConfig)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This device'),
                  value: enabled,
                  onChanged: isSaving
                      ? null
                      : (value) =>
                            updatePreference(value, context, setDialogState),
                )
              else
                const Text(
                  'Push notifications are not available in this app build.',
                ),
              if (isSaving) const LinearProgressIndicator(),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _confirmDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Request account deletion?'),
        content: const Text(
          'This opens a support request for review. Your account will remain active until the request is processed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  if (confirmed == true && context.mounted) {
    _openSupportRequest(
      context,
      category: 'privacy',
      subject: 'Request account deletion',
      message:
          'I want to request deletion of my Veedufix account. Please explain any required verification and the next steps.',
    );
  }
}

void _openSupportRequest(
  BuildContext context, {
  required String category,
  required String subject,
  required String message,
}) {
  context.push(
    '/support?autoCompose=true&category=${Uri.encodeComponent(category)}'
    '&subject=${Uri.encodeComponent(subject)}&message=${Uri.encodeComponent(message)}',
  );
}

Future<void> _openLegalPage(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this page.')));
  }
}
