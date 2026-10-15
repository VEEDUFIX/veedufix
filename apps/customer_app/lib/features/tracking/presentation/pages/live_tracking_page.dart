import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/tracking_providers.dart';

class LiveTrackingPage extends ConsumerStatefulWidget {
  const LiveTrackingPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends ConsumerState<LiveTrackingPage> {
  GoogleMapController? _mapController;
  Timer? _freshnessTimer;
  // Use a neutral country-level view until either booking coordinate is known.
  static const _fallbackCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _freshnessTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final booking = bookingAsync.valueOrNull;
    final trackingEnded = const {
      'ARRIVED',
      'IN_PROGRESS',
      'COMPLETED',
      'CANCELLED',
      'CANCELLED_MANUAL',
      'CANCELLED_NO_SHOW',
      'REFUNDED',
    }.contains(booking?.status.toUpperCase());
    final AsyncValue<WorkerLocation?> workerLocationAsync = trackingEnded
        ? const AsyncData<WorkerLocation?>(null)
        : ref.watch(workerLocationProvider(widget.bookingId));
    final destinationLatitude = booking?.destinationLatitude;
    final destinationLongitude = booking?.destinationLongitude;
    final customerLocation = _latLngForCoordinates(
      destinationLatitude,
      destinationLongitude,
    );
    final workerLocation = trackingEnded
        ? null
        : workerLocationAsync.valueOrNull;
    final locationAge = workerLocation == null
        ? null
        : DateTime.now().difference(workerLocation.timestamp);
    final locationIsStale =
        workerLocation != null && !workerLocation.isFreshAt(DateTime.now());
    final liveWorkerLocation = locationIsStale
        ? null
        : _latLngForCoordinates(
            workerLocation?.latitude,
            workerLocation?.longitude,
          );
    final mapCenter = liveWorkerLocation ?? customerLocation ?? _fallbackCenter;
    final mapFocusLocation = liveWorkerLocation ?? customerLocation;
    final trackingStatusColor = trackingEnded
        ? cs.onSurfaceVariant
        : workerLocationAsync.hasError
        ? AbzioTheme.dangerColor
        : locationIsStale
        ? AbzioTheme.warningColor
        : liveWorkerLocation != null
        ? AbzioTheme.successColor
        : cs.primary;
    final workerName = booking?.worker?.name ?? 'Professional';
    final workerRating = booking?.worker?.rating ?? 0.0;
    final workerInitial = workerName.trim().isNotEmpty
        ? workerName.trim()[0].toUpperCase()
        : 'P';

    if (!trackingEnded) {
      ref.listen(workerLocationProvider(widget.bookingId), (prev, next) {
        final loc = next.valueOrNull;
        final target = _latLngForCoordinates(loc?.latitude, loc?.longitude);
        if (target != null && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(target));
        }
      });
    }
    ref.listen(bookingDetailProvider(widget.bookingId), (previous, next) {
      if (trackingEnded) return;
      if (ref.read(workerLocationProvider(widget.bookingId)).valueOrNull !=
          null) {
        return;
      }
      final address = next.valueOrNull;
      final latitude = address?.destinationLatitude;
      final longitude = address?.destinationLongitude;
      final target = _latLngForCoordinates(latitude, longitude);
      if (target != null && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(target));
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen Google Map ──────────────────────────────────────
          if (customerLocation != null || liveWorkerLocation != null)
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mapCenter,
                zoom: 14.5,
              ),
              onMapCreated: (controller) => _mapController = controller,
              markers: {
                if (customerLocation != null)
                  Marker(
                    markerId: const MarkerId('customer'),
                    position: customerLocation,
                    infoWindow: const InfoWindow(title: 'Service address'),
                  ),
                if (liveWorkerLocation != null)
                  Marker(
                    markerId: const MarkerId('professional'),
                    position: liveWorkerLocation,
                    rotation: workerLocation!.heading,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
                    infoWindow: InfoWindow(title: '$workerName is here'),
                  ),
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            )
          else
            ColoredBox(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_searching_rounded,
                        size: 42,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Map location not available yet',
                        textAlign: TextAlign.center,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The map will appear when address or professional location is available.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (customerLocation != null || liveWorkerLocation != null)
            Positioned(
              right: 16,
              bottom: MediaQuery.sizeOf(context).height * 0.58 + 8,
              child: SafeArea(
                child: Material(
                  color: cs.surface,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: liveWorkerLocation != null
                        ? 'Center map on professional'
                        : 'Center map on service address',
                    onPressed: mapFocusLocation == null
                        ? null
                        : () => _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              mapFocusLocation,
                              liveWorkerLocation == null ? 14.5 : 15.5,
                            ),
                          ),
                    icon: const Icon(Icons.my_location_rounded),
                  ),
                ),
              ),
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
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: trackingStatusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AbzioTheme.cardRadius,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: trackingStatusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _trackingStatus(
                                    liveWorkerLocation,
                                    locationIsStale,
                                    booking?.status,
                                    workerLocationAsync.hasError,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: workerLocationAsync.hasError
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  style: tt.labelLarge?.copyWith(
                                    color: trackingStatusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (workerLocationAsync.hasError)
                                IconButton(
                                  tooltip: 'Retry live location',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => ref.invalidate(
                                    workerLocationProvider(widget.bookingId),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded),
                                ),
                            ],
                          ),
                        ),
                        if (workerLocation != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            locationIsStale
                                ? '${_lastUpdatedLabel(locationAge)} · location is no longer live'
                                : _lastUpdatedLabel(locationAge),
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !trackingEnded &&
                                      !locationIsStale &&
                                      workerLocation?.etaMinutes != null
                                  ? 'Road ETA about ${workerLocation!.etaMinutes} min'
                                  : 'Road ETA unavailable',
                              style: tt.labelMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Professional info row
                        if (booking?.worker != null)
                          Row(
                            children: [
                              MarketplaceNetworkAvatar(
                                imageUrl: booking?.worker?.avatarUrl,
                                radius: 26,
                                backgroundColor: const Color(
                                  0xFFC2A15E,
                                ).withValues(alpha: 0.15),
                                fallback: Text(
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
                                    Text(
                                      workerName,
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (workerRating > 0)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 14,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${workerRating.toStringAsFixed(1)}  ·  Professional',
                                            style: tt.bodySmall?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'Veedufix professional',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: 'Chat with professional',
                                onPressed: () => context.push(
                                  '/chat?bookingId=${widget.bookingId}',
                                ),
                                icon: const Icon(Icons.chat_rounded),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: cs.primary.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  Icons.person_search_rounded,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Professional details will appear here after assignment.',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.tonalIcon(
                            onPressed: () =>
                                context.push('/booking/${widget.bookingId}'),
                            icon: const Icon(Icons.receipt_long_rounded),
                            label: const Text('View booking details'),
                          ),
                        ),
                      ],
                    ),
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

bool _hasValidCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

LatLng? _latLngForCoordinates(double? latitude, double? longitude) {
  if (latitude == null ||
      longitude == null ||
      !_hasValidCoordinates(latitude, longitude)) {
    return null;
  }
  return LatLng(latitude, longitude);
}

String _trackingStatus(
  LatLng? workerLatLng,
  bool isStale,
  String? bookingStatus,
  bool hasLocationError,
) {
  final normalizedStatus = bookingStatus?.toUpperCase();
  if (normalizedStatus == 'ARRIVED') return 'Partner has arrived';
  if (normalizedStatus == 'IN_PROGRESS') return 'Service is in progress';
  if (const {
    'COMPLETED',
    'CANCELLED',
    'CANCELLED_MANUAL',
    'CANCELLED_NO_SHOW',
    'REFUNDED',
  }.contains(normalizedStatus)) {
    return 'Live tracking ended';
  }
  if (hasLocationError) return 'Live location unavailable';
  if (isStale) return 'Last location update is delayed';
  if (workerLatLng == null) {
    return normalizedStatus == 'PENDING'
        ? 'Waiting for professional assignment'
        : 'Waiting for first location update';
  }
  return 'Professional location is live';
}

String _lastUpdatedLabel(Duration? age) {
  if (age == null || age.isNegative) return 'Location update time unavailable';
  if (age.inSeconds < 60) return 'Location updated just now';
  if (age.inMinutes < 60) return 'Location updated ${age.inMinutes} min ago';
  return 'Location updated ${age.inHours} hr ago';
}
