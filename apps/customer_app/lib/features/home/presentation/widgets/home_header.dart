import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../profile/presentation/pages/map_location_picker_page.dart';
import '../../../profile/presentation/providers/selected_location_provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.location,
    this.bright = false,
  });

  final String location;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final secondary =
        bright ? Colors.white.withValues(alpha: 0.82) : AbzioTheme.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocationChip(location: location, bright: bright),
              const SizedBox(height: 5),
              Text(
                'Home services delivered fast',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        TapScale(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bright ? Colors.white : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_outline_rounded,
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
  const LocationChip({
    super.key,
    required this.location,
    this.bright = false,
  });

  final String location;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () async {
        final selection = await context.push<MapLocationSelection>('/map-picker');
        if (selection == null || !context.mounted) {
          return;
        }
        final container = ProviderScope.containerOf(context, listen: false);
        await container.read(selectedLocationProvider.notifier).setLocation(
              latitude: selection.latitude,
              longitude: selection.longitude,
              label: selection.label,
            );
      },
      child: Container(
        padding: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.my_location_rounded,
              size: 20,
              color: bright ? Colors.white : AbzioTheme.accentColor,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                location,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: bright ? Colors.white : AbzioTheme.lightTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: bright
                  ? Colors.white.withValues(alpha: 0.9)
                  : AbzioTheme.lightTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
