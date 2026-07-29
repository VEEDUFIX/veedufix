import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        actions: actions,
        iconTheme: const IconThemeData(color: Colors.black87),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAdminBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: kAdminInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: kAdminMuted,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}
