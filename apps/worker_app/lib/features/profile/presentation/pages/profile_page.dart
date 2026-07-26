import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          PremiumGlassCard(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 24,
                child: Text(_initial(auth?.user.name)),
              ),
              title: Text(
                auth?.user.name ?? 'Guest',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(auth?.user.role ?? 'WORKER'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(
            title: 'Account',
            subtitle: 'Update your work profile and service preferences.',
          ),
          const SizedBox(height: 12),
          const _ProfileTile(icon: Icons.location_on_outlined, title: 'Saved addresses'),
          const _ProfileTile(icon: Icons.wallet_outlined, title: 'Wallet'),
          const _ProfileTile(icon: Icons.star_outline_rounded, title: 'Reviews'),
          const _ProfileTile(icon: Icons.support_agent_rounded, title: 'Support'),
          const SizedBox(height: 16),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
