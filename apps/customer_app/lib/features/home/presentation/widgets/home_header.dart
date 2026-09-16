import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/customer_logo.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.greeting,
    required this.name,
    required this.location,
  });

  final String greeting;
  final String name;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ─── Left: Logo + greeting ──────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CustomerLogo(height: 26),
              const SizedBox(height: 14),
              Text(
                greeting,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AbzioTheme.lightTextSecondary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$name 👋',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AbzioTheme.lightTextPrimary,
                  letterSpacing: -0.4,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              LocationChip(location: location),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // ─── Right: Notification button ─────────────────────────
        TapScale(
          onTap: () => context.push('/notifications'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AbzioTheme.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 22,
              color: AbzioTheme.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class LocationChip extends StatelessWidget {
  const LocationChip({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => context.push('/map-picker'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AbzioTheme.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.my_location_rounded,
              size: 14,
              color: AbzioTheme.accentColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                location,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AbzioTheme.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AbzioTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
