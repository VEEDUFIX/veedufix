import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({super.key, this.initialPosition});

  /// If provided, the map starts here. Otherwise defaults to Kochi.
  final LatLng? initialPosition;

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage>
    with SingleTickerProviderStateMixin {
  static const _defaultCenter = LatLng(10.0261, 76.3125); // Kochi, Kerala

  late LatLng _currentCenter;
  bool _isDragging = false;

  final Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _pinBounce;
  late Animation<double> _pinOffset;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition ?? _defaultCenter;
    _pinBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinOffset = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _pinBounce, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pinBounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            onCameraMoveStarted: () {
              setState(() => _isDragging = true);
              _pinBounce.forward();
            },
            onCameraMove: (pos) {
              _currentCenter = pos.target;
            },
            onCameraIdle: () {
              setState(() => _isDragging = false);
              _pinBounce.reverse();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Fixed center pin ────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36), // offset so pin base is at center
              child: AnimatedBuilder(
                animation: _pinOffset,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _pinOffset.value),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: cs.primary,
                      shadows: [
                        Shadow(
                          color: cs.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    // Pin shadow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isDragging ? 8 : 4,
                      height: _isDragging ? 8 : 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isDragging ? 0.2 : 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  TapScale(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search for a location...',
                        hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),

          // ── My location FAB ─────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 200,
            child: TapScale(
              onTap: () async {
                final controller = await _mapController.future;
                controller.animateCamera(
                  CameraUpdate.newLatLng(_currentCenter),
                );
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.my_location_rounded, color: cs.primary),
              ),
            ),
          ),

          // ── Bottom confirm card ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected Location',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                      key: ValueKey('${_currentCenter.latitude}_${_currentCenter.longitude}'),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TapScale(
                    onTap: () => context.pop(_currentCenter),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Confirm Location',
                          style: tt.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
