import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider.select((s) => s.valueOrNull));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Account Profile',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your admin identity and system preferences.',
              style: GoogleFonts.inter(
                color: Colors.black54,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),

            // Profile Card
            Container(
              width: 600,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
                          child: Text(
                            _initial(auth?.user.name),
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth?.user.name ?? 'Admin User',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                auth?.user.role ?? 'ADMIN',
                                style: GoogleFonts.inter(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const _ProfileSettingRow(
                    icon: Icons.security_rounded,
                    title: 'Authentication',
                    subtitle: 'Google Workspace Single Sign-On',
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const _ProfileSettingRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage email and dashboard alerts',
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const _ProfileSettingRow(
                    icon: Icons.language_rounded,
                    title: 'Region',
                    subtitle: 'India (IST)',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Logout Button
            FilledButton.icon(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out of Admin Panel'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444), // Red for destructive action
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return 'A';
    return name[0].toUpperCase();
  }
}

class _ProfileSettingRow extends StatelessWidget {
  const _ProfileSettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.black54, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
