import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    required this.subtitle,
    this.onSeeAll,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AbzioTheme.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AbzioTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See all',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AbzioTheme.accentColor,
              ),
            ),
          ),
      ],
    );
  }
}
