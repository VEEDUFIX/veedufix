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
    return WorkerLocation(
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: json.containsKey('timestamp') 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

final workerLocationProvider = StreamProvider.family<WorkerLocation?, String>((ref, bookingId) {
  final realtime = ref.read(realtimeServiceProvider);
  
  ref.onDispose(() {
    realtime.disconnectTracking();
  });

  // Automatically connect when this provider is first watched
  realtime.connectTracking(bookingId);

  return realtime.trackingStream.map((payload) {
    // Check if the payload contains lat/lng from a worker
    if (payload['lat'] != null && payload['lng'] != null) {
      return WorkerLocation.fromJson(payload);
    }
    return null;
  });
});
