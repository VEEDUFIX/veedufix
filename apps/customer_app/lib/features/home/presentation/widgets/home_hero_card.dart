import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.name,
    required this.featuredCategories,
    required this.nearbyProfessionals,
    required this.location,
  });

  final String name;
  final int featuredCategories;
  final int nearbyProfessionals;
  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2A1F00),
            Color(0xFF3D2C00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AbzioTheme.accentColor.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Subtle decorative circle top-right
            Positioned(
              top: -32,
              right: -32,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AbzioTheme.accentColor.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + headline
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.handyman_rounded,
                          color: AbzioTheme.accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What do you need fixed?',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Trusted professionals near $location, ready to help.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _StatPill(
                        icon: Icons.category_rounded,
                        label: '$featuredCategories Services',
                      ),
                      const SizedBox(width: 8),
                      _StatPill(
                        icon: Icons.verified_rounded,
                        label: '$nearbyProfessionals Nearby',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CTA buttons
                  Row(
                    children: [
                      Expanded(
                        child: TapScale(
                          onTap: () => context.push('/search'),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: AbzioTheme.accentColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Find a service',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TapScale(
                        onTap: () => context.push('/bookings'),
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'My bookings',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AbzioTheme.accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
