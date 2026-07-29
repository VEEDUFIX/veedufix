import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late Future<OpsOverviewSnapshot> _snapshotFuture;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(10.0261, 76.3125), // Default to Kochi
    zoom: 11,
  );

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _api.fetchOverview();
  }

  Set<Marker> _buildMarkers(OpsOverviewSnapshot data) {
    final markers = <Marker>{};

    for (final job in data.liveJobs) {
      // For demonstration, adding a slight offset since actual coords are not fully mocked in OpsLiveJob yet.
      // In a real app, OpsLiveJob would have lat/lng.
      markers.add(
        Marker(
          markerId: MarkerId('job_${job.bookingId}'),
          position: const LatLng(10.0261, 76.3125),
          infoWindow: InfoWindow(
            title: '${job.bookingCode} - ${job.customerName}',
            snippet: job.statusLabel,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('God-Mode Live Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _snapshotFuture = _api.fetchOverview();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<OpsOverviewSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load live map',
                subtitle: snapshot.error.toString(),
              ),
            );
          }

          final data = snapshot.data!;
          final markers = _buildMarkers(data);

          return GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: markers,
            myLocationEnabled: false,
            zoomControlsEnabled: true,
          );
        },
      ),
    );
  }
}
