import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

const Color kAdminCanvas = Colors.transparent;
const Color kAdminCanvasAlt = Colors.transparent;
const Color kAdminInk = Colors.black87;
const Color kAdminMuted = Colors.black54;
const Color kAdminBorder = Color(0xFFE5E7EB);

class AdminPageShell extends StatelessWidget {
  const AdminPageShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        actions: actions,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      body: child,
    );
  }
}

class AdminSurfacePanel extends StatelessWidget {
  const AdminSurfacePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: AbzioTheme.shadowFor(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
