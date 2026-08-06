import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/tracking_providers.dart';

class LiveTrackingPage extends ConsumerStatefulWidget {
  const LiveTrackingPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends ConsumerState<LiveTrackingPage>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const _chennaiCenter = LatLng(13.0827, 80.2707);
  LatLng? _customerLatLng;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _customerLatLng = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final workerLocationAsync = ref.watch(workerLocationProvider(widget.bookingId));
    final liveWorkerLocation = workerLocationAsync.valueOrNull != null 
        ? LatLng(workerLocationAsync.valueOrNull!.latitude, workerLocationAsync.valueOrNull!.longitude) 
        : _customerLatLng ?? _chennaiCenter;

    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final workerName = bookingAsync.valueOrNull?.worker?.name ?? 'Professional';
    final workerRating = bookingAsync.valueOrNull?.worker?.rating ?? 0.0;
    final workerInitial = workerName.isNotEmpty ? workerName[0].toUpperCase() : 'P';

    ref.listen(workerLocationProvider(widget.bookingId), (prev, next) {
      final loc = next.valueOrNull;
      if (loc != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Google Map ──────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: workerLocationAsync.valueOrNull != null ? liveWorkerLocation : (_customerLatLng ?? _chennaiCenter),
              zoom: 14.5,
            ),
            onMapCreated: (c) => _mapController = c,
            markers: {
              Marker(
                markerId: const MarkerId('customer'),
                position: _customerLatLng ?? _chennaiCenter,
                infoWindow: const InfoWindow(title: 'Your Location'),
              ),
              Marker(
                markerId: const MarkerId('professional'),
                position: liveWorkerLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
                infoWindow: InfoWindow(title: '$workerName is here'),
              ),
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                color: cs.primary,
                width: 5,
                points: [_customerLatLng ?? _chennaiCenter, liveWorkerLocation],
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Back button ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TapScale(
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
            ),
          ),

          // ── Bottom info sheet ────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // ETA pill (animated pulse)
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnim.value,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _etaString(liveWorkerLocation, _customerLatLng),
                                style: tt.labelLarge?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Professional info row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFC2A15E)
                                .withValues(alpha: 0.15),
                            child: Text(
                              workerInitial,
                              style: tt.titleLarge?.copyWith(
                                color: const Color(0xFFC2A15E),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(workerName,
                                    style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 14,
                                        color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text('${workerRating.toStringAsFixed(1)}  ·  Professional',
                                        style: tt.bodySmall?.copyWith(
                                            color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Chat button
                          TapScale(
                            onTap: () => context.push(
                                '/chat?bookingId=${widget.bookingId}'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_rounded,
                                  color: cs.primary, size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Message button (also opens chat — keeps phone numbers masked)
                          TapScale(
                            onTap: () => context.push(
                                '/chat?bookingId=${widget.bookingId}'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.message_rounded,
                                  color: Color(0xFF10B981), size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SOS / Cancel row
                      Row(
                        children: [
                          Expanded(
                            child: TapScale(
                              onTap: () => context.push('/booking/${widget.bookingId}'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius:
                                      BorderRadius.circular(AbzioTheme.buttonRadius),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cancel_outlined,
                                        color: cs.error, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Cancel',
                                        style: tt.labelLarge?.copyWith(
                                            color: cs.error,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TapScale(
                              onTap: () => context.push('/booking/${widget.bookingId}'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                                  boxShadow: AbzioTheme.eliteShadow,
                                ),
                                child: Text(
                                  'View Booking',
                                  textAlign: TextAlign.center,
                                  style: tt.labelLarge?.copyWith(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
          ),
        ],
      ),
    );
  }
}

/// Haversine distance in km between two LatLng points.
double _haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final sinLat = math.sin(dLat / 2);
  final sinLng = math.sin(dLng / 2);
  final c = sinLat * sinLat +
      math.cos(a.latitude * math.pi / 180) *
          math.cos(b.latitude * math.pi / 180) *
          sinLng * sinLng;
  return 2 * r * math.asin(math.sqrt(c));
}

/// Returns a human-readable ETA string based on Haversine distance at 20 km/h.
String _etaString(LatLng workerLatLng, LatLng? customerLatLng) {
  if (customerLatLng == null) return 'On the way';
  final distKm = _haversineKm(workerLatLng, customerLatLng);
  // 20 km/h average in Chennai city traffic + 5 min parking/setup buffer
  final mins = (distKm / 20 * 60).ceil() + 5;
  if (mins <= 1) return 'Arriving now';
  return 'Arriving in $mins min';
}
