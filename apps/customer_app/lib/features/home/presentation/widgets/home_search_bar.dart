import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.hint,
    required this.onVoiceTap,
  });

  final String hint;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => context.push('/search'),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AbzioTheme.lightBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: AbzioTheme.lightTextSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hint,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AbzioTheme.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Divider
            Container(
              width: 1,
              height: 24,
              color: AbzioTheme.lightBorder,
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onVoiceTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  size: 18,
                  color: AbzioTheme.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
