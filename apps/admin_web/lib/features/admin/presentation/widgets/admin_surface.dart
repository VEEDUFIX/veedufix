import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color kAdminCanvas = Color(0xFFF9F5EC);
const Color kAdminCanvasAlt = Color(0xFFFFFCF8);
const Color kAdminInk = Color(0xFF13110F);
const Color kAdminMuted = Color(0xFF6B6256);
const Color kAdminBorder = Color(0xFFE5D8C6);

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
      backgroundColor: kAdminCanvas,
      appBar: AppBar(
        backgroundColor: kAdminCanvas,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: actions,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kAdminCanvas, kAdminCanvasAlt],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: child,
      ),
    );
  }
}

class AdminSurfacePanel extends StatelessWidget {
  const AdminSurfacePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: kAdminBorder),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
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
