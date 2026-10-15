import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/ops_api.dart';

class GodModeMapPage extends ConsumerStatefulWidget {
  const GodModeMapPage({super.key});

  @override
  ConsumerState<GodModeMapPage> createState() => _GodModeMapPageState();
}

class _GodModeMapPageState extends ConsumerState<GodModeMapPage> {
  late final OpsApi _api;
  OpsOverviewSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  String? _lastFittedLocationsKey;
  String? _fittingLocationsKey;
  Set<String> _knownLocatedJobIds = <String>{};

  static const LatLng _neutralMapCenter = LatLng(20.5937, 78.9629);

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _load();
    // Auto-refresh every 30 s so admins see live field updates.
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // The GoogleMap widget owns and disposes its controller.
    _mapController = null;
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = _snapshot == null; // only full-screen spinner on first load
      _error = null;
    });
    try {
      final data = await _api.fetchOverview();
      if (!mounted) return;
      setState(() {
        _snapshot = data;
        _loading = false;
      });
      unawaited(_fitLocatedJobs(data));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fitLocatedJobs(OpsOverviewSnapshot snapshot) async {
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) return;
    final locations = snapshot.liveJobs
        .where((job) => job.workerLat != null && job.workerLng != null)
        .map((job) => LatLng(job.workerLat!, job.workerLng!))
        .toList(growable: false);
    if (locations.isEmpty) {
      _lastFittedLocationsKey = null;
      return;
    }

    final locatedJobIds = snapshot.liveJobs
        .where((job) => job.workerLat != null && job.workerLng != null)
        .map((job) => job.bookingId)
        .toSet();
    final hasNewLocatedJob =
        locatedJobIds.difference(_knownLocatedJobIds).isNotEmpty;
    if (_lastFittedLocationsKey != null && !hasNewLocatedJob) return;
    final sortedJobIds = locatedJobIds.toList()..sort();
    final key = sortedJobIds.join('|');
    if (_lastFittedLocationsKey == key || _fittingLocationsKey == key) return;
    _fittingLocationsKey = key;

    try {
      if (locations.length == 1) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(locations.single, 12),
        );
      } else {
        var south = locations.first.latitude;
        var north = south;
        var west = locations.first.longitude;
        var east = west;
        for (final location in locations.skip(1)) {
          south = math.min(south, location.latitude).toDouble();
          north = math.max(north, location.latitude).toDouble();
          west = math.min(west, location.longitude).toDouble();
          east = math.max(east, location.longitude).toDouble();
        }
        if (south == north && west == east) {
          await controller.animateCamera(
            CameraUpdate.newLatLngZoom(locations.first, 12),
          );
        } else {
          await controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(south, west),
                northeast: LatLng(north, east),
              ),
              64,
            ),
          );
        }
      }
      _lastFittedLocationsKey = key;
      _knownLocatedJobIds = locatedJobIds;
    } catch (_) {
      // Map layout may not be ready during the first callback; a later load can retry.
    } finally {
      if (_fittingLocationsKey == key) _fittingLocationsKey = null;
    }
  }

  Set<Marker> _buildMarkers(OpsOverviewSnapshot data) {
    final markers = <Marker>{};

    for (final job in data.liveJobs) {
      if (job.workerLat == null || job.workerLng == null) continue;

      // Colour-code by status: in-progress = blue, others = red.
      final hue = job.status.toLowerCase() == 'in_progress'
          ? BitmapDescriptor.hueBlue
          : BitmapDescriptor.hueRed;

      markers.add(
        Marker(
          markerId: MarkerId('job_${job.bookingId}'),
          position: LatLng(job.workerLat!, job.workerLng!),
          infoWindow: InfoWindow(
            title: '${job.bookingCode} — ${job.customerName}',
            snippet: '${job.statusLabel} · ${job.workerName ?? "Unassigned"}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final liveCount = _snapshot?.liveJobs.length ?? 0;
    final inProgress = _snapshot?.liveJobs
            .where((job) => job.status.toLowerCase() == 'in_progress')
            .length ??
        0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'God-Mode Live Map',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        actions: [
          // Live job count badge
          if (_snapshot != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: liveCount > 0
                      ? const Color(0xFF0F766E).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        liveCount > 0 ? const Color(0xFF0F766E) : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Text(
                  '$liveCount live · $inProgress active',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        liveCount > 0 ? const Color(0xFF0F766E) : Colors.grey,
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh now',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map layer ──────────────────────────────────────────────────
          if (_snapshot != null)
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _neutralMapCenter,
                zoom: 4.5,
              ),
              onMapCreated: (controller) {
                if (!mounted) return;
                _mapController = controller;
                unawaited(_fitLocatedJobs(_snapshot!));
              },
              markers: _buildMarkers(_snapshot!),
              myLocationEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load live map',
                subtitle: _error!,
              ),
            ),

          // ── Legend overlay (bottom-left) ───────────────────────────────
          if (_snapshot != null)
            Positioned(
              left: 12,
              bottom: 32,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Legend',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const _LegendDot(
                      color: Colors.blue,
                      label: 'In Progress',
                    ),
                    const SizedBox(height: 4),
                    const _LegendDot(
                      color: Colors.red,
                      label: 'Other active',
                    ),
                  ],
                ),
              ),
            ),

          // ── Stale-data refresh indicator ───────────────────────────────
          if (_loading && _snapshot != null)
            const Positioned(
              top: 12,
              right: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }
}
