import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AbzioTheme.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AbzioTheme.lightTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TapScale(
            onTap: onSeeAll!,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'See all',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.accentColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
