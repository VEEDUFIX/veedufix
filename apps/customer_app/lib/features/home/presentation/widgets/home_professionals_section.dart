import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({super.key, required this.professional});

  final HomeProfessional professional;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: TapScale(
        onTap: professional.id.isEmpty
            ? null
            : () => context.push(
                Uri(
                  path: '/professional',
                  queryParameters: {'id': professional.id},
                ).toString(),
              ),
        child: Semantics(
          button: professional.id.isNotEmpty,
          label:
              '${professional.name}, ${professional.verified ? 'verified professional' : 'professional'}, ${professional.rating > 0 ? 'rated ${professional.rating.toStringAsFixed(1)} stars' : 'new'}, ${professional.distance}',
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AbzioTheme.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AbzioTheme.lightMuted,
                      child: Text(
                        professional.name.isNotEmpty
                            ? professional.name[0]
                            : '',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AbzioTheme.accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  professional.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AbzioTheme.lightTextPrimary,
                                  ),
                                ),
                              ),
                              if (professional.verified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: AbzioTheme.successColor,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            professional.role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: AbzioTheme.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AbzioTheme.lightMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (professional.rating > 0) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: AbzioTheme.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              professional.rating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AbzioTheme.lightTextPrimary,
                              ),
                            ),
                          ] else
                            Text(
                              'New',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AbzioTheme.lightTextSecondary,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        professional.distance,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AbzioTheme.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        professional.price,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AbzioTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        professional.experience,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AbzioTheme.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
