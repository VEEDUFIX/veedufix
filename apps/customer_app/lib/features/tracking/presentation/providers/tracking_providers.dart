import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerLocation {
  const WorkerLocation({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double heading;
  final DateTime timestamp;

  factory WorkerLocation.fromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse(json['lat']?.toString() ?? '');
    final longitude = double.tryParse(json['lng']?.toString() ?? '');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid worker coordinates');
    }
    final parsedHeading =
        double.tryParse(json['heading']?.toString() ?? '') ?? 0.0;
    return WorkerLocation(
      latitude: latitude,
      longitude: longitude,
      heading: parsedHeading.isFinite
          ? ((parsedHeading % 360) + 360) % 360
          : 0.0,
      timestamp: json.containsKey('timestamp')
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

final workerLocationProvider = StreamProvider.autoDispose
    .family<WorkerLocation?, String>((ref, bookingId) {
      final realtime = ref.read(realtimeServiceProvider);
      var disposed = false;
      final connection = realtime.connectTracking(bookingId);

      ref.onDispose(() {
        disposed = true;
        unawaited(realtime.disconnectTracking());
      });
      unawaited(
        connection.then((_) {
          if (disposed) unawaited(realtime.disconnectTracking());
        }, onError: (_) {}),
      );

      return realtime.trackingStream.map((payload) {
        // Check if the payload contains lat/lng from a worker
        if (payload['lat'] != null && payload['lng'] != null) {
          try {
            return WorkerLocation.fromJson(payload);
          } on FormatException {
            return null;
          }
        }
        return null;
      });
    });
