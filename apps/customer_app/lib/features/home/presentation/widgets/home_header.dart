import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../profile/presentation/pages/map_location_picker_page.dart';
import '../../../profile/presentation/providers/selected_location_provider.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.location, this.bright = false});

  final String location;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Align(
        alignment: Alignment.centerLeft,
        child: LocationChip(location: location, bright: bright),
      ),
    );
  }
}

class LocationChip extends StatelessWidget {
  const LocationChip({super.key, required this.location, this.bright = false});

  final String location;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () async {
        final selection = await context.push<MapLocationSelection>(
          '/map-picker',
        );
        if (selection == null || !context.mounted) {
          return;
        }
        try {
          final container = ProviderScope.containerOf(context, listen: false);
          await container
              .read(selectedLocationProvider.notifier)
              .setLocation(
                latitude: selection.latitude,
                longitude: selection.longitude,
                label: selection.label,
              );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not save this location. Please try again.',
                ),
              ),
            );
        }
      },
      child: Semantics(
        button: true,
        label: 'Change service location. Current location: $location',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: bright ? Colors.white : AbzioTheme.accentColor,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  location,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: bright ? Colors.white : AbzioTheme.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: bright
                    ? Colors.white.withValues(alpha: 0.9)
                    : AbzioTheme.lightTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
