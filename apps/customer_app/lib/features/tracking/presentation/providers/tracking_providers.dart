import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerLocation {
  const WorkerLocation({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.timestamp,
    this.etaMinutes,
  });

  final double latitude;
  final double longitude;
  final double heading;
  final DateTime timestamp;
  final int? etaMinutes;

  bool isAtLeastAsRecentAs(DateTime? previousTimestamp) =>
      previousTimestamp == null || !timestamp.isBefore(previousTimestamp);

  bool isFreshAt(DateTime now, {Duration maxAge = const Duration(minutes: 2)}) {
    final age = now.difference(timestamp);
    return !age.isNegative && age <= maxAge;
  }

  factory WorkerLocation.fromJson(
    Map<String, dynamic> json, {
    int? fallbackEtaMinutes,
  }) {
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
    final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    if (timestamp == null) {
      throw const FormatException('Missing worker location timestamp');
    }
    final eta = json.containsKey('etaMinutes')
        ? int.tryParse(json['etaMinutes']?.toString() ?? '')
        : fallbackEtaMinutes;
    return WorkerLocation(
      latitude: latitude,
      longitude: longitude,
      heading: parsedHeading.isFinite
          ? ((parsedHeading % 360) + 360) % 360
          : 0.0,
      timestamp: timestamp,
      etaMinutes: eta != null && eta > 0 ? eta : null,
    );
  }
}

final workerLocationProvider = StreamProvider.autoDispose
    .family<WorkerLocation?, String>((ref, bookingId) {
      final realtime = ref.read(realtimeServiceProvider);
      final api = ref.read(apiClientProvider);
      final events = realtime.trackingStream;
      final connection = realtime.connectTracking(bookingId);
      var disposed = false;
      int? snapshotEtaMinutes;
      DateTime? lastEmittedTimestamp;
      String? lastObservedStatus;
      StreamSubscription<Map<String, dynamic>>? eventSubscription;
      Timer? refreshTimer;
      final stream = Stream<WorkerLocation?>.multi((controller) {
        void emitIfNotOlder(WorkerLocation location) {
          if (!location.isAtLeastAsRecentAs(lastEmittedTimestamp)) return;
          lastEmittedTimestamp = location.timestamp;
          controller.add(location);
        }

        void refreshBookingDetailsWhenStatusChanges(Object? rawStatus) {
          final status = rawStatus?.toString();
          if (status == null || status == lastObservedStatus) return;
          lastObservedStatus = status;
          if (status != 'EN_ROUTE') {
            ref.invalidate(bookingDetailProvider(bookingId));
          }
        }

        Future<void> refreshSnapshot() async {
          try {
            final snapshot = await api.get('/bookings/$bookingId/tracking');
            if (disposed) return;
            refreshBookingDetailsWhenStatusChanges(snapshot['status']);
            if (snapshot['status'] != 'EN_ROUTE') {
              snapshotEtaMinutes = null;
              controller.add(null);
              return;
            }
            final snapshotEta = int.tryParse(
              snapshot['etaMinutes']?.toString() ?? '',
            );
            snapshotEtaMinutes = snapshotEta != null && snapshotEta > 0
                ? snapshotEta
                : null;
            final location = snapshot['location'];
            if (location is Map<String, dynamic>) {
              try {
                emitIfNotOlder(
                  WorkerLocation.fromJson({
                    ...location,
                    'etaMinutes': snapshot['etaMinutes'],
                  }),
                );
              } on FormatException {
                controller.add(null);
              }
            } else {
              controller.add(null);
            }
          } catch (error, stackTrace) {
            if (!disposed) controller.addError(error, stackTrace);
          }
        }

        unawaited(() async {
          try {
            await connection;
            if (disposed) return;
            eventSubscription = events.listen((payload) {
              refreshBookingDetailsWhenStatusChanges(payload['status']);
              if (payload['status'] != null &&
                  payload['status'] != 'EN_ROUTE') {
                controller.add(null);
                return;
              }
              if (payload['lat'] == null || payload['lng'] == null) return;
              try {
                emitIfNotOlder(
                  WorkerLocation.fromJson(
                    payload,
                    fallbackEtaMinutes: snapshotEtaMinutes,
                  ),
                );
              } on FormatException {
                controller.add(null);
              }
            });
            await refreshSnapshot();
            if (disposed) return;
            refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
              unawaited(refreshSnapshot());
            });
          } catch (error, stackTrace) {
            if (!disposed) controller.addError(error, stackTrace);
          }
        }());
        controller.onCancel = () {
          disposed = true;
          refreshTimer?.cancel();
          unawaited(eventSubscription?.cancel());
          unawaited(realtime.disconnectTracking());
        };
      });
      ref.onDispose(() {
        disposed = true;
        refreshTimer?.cancel();
        unawaited(eventSubscription?.cancel());
        unawaited(realtime.disconnectTracking());
      });
      return stream;
    });
