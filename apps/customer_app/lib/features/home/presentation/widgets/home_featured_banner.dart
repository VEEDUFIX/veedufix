import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeFeaturedBanner extends StatelessWidget {
  const HomeFeaturedBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onAction,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AbzioTheme.lightMuted,
          border: Border.all(color: AbzioTheme.lightBorder),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Left: text + CTA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'FEATURED',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AbzioTheme.accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AbzioTheme.lightTextPrimary,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: AbzioTheme.lightTextSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right: icon
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AbzioTheme.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 38,
                color: AbzioTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
