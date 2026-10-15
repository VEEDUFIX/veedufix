import 'package:flutter_test/flutter_test.dart';
import 'package:customer_app/features/tracking/presentation/providers/tracking_providers.dart';

void main() {
  group('WorkerLocation', () {
    final now = DateTime.utc(2026, 10, 10, 12);

    test(
      'parses coordinates, normalizes heading, and accepts a positive ETA',
      () {
        final location = WorkerLocation.fromJson({
          'lat': 13.0827,
          'lng': 80.2707,
          'heading': -10,
          'timestamp': now.toIso8601String(),
          'etaMinutes': 12,
        });

        expect(location.latitude, 13.0827);
        expect(location.longitude, 80.2707);
        expect(location.heading, 350);
        expect(location.etaMinutes, 12);
      },
    );

    test('rejects invalid coordinates and missing timestamps', () {
      expect(
        () => WorkerLocation.fromJson({
          'lat': 91,
          'lng': 80,
          'timestamp': now.toIso8601String(),
        }),
        throwsFormatException,
      );
      expect(
        () => WorkerLocation.fromJson({'lat': 13, 'lng': 80}),
        throwsFormatException,
      );
    });

    test('does not expose non-positive ETA values', () {
      final location = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.toIso8601String(),
        'etaMinutes': 0,
      });

      expect(location.etaMinutes, isNull);
    });

    test('uses the latest snapshot ETA when a realtime event omits it', () {
      final location = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.toIso8601String(),
      }, fallbackEtaMinutes: 12);

      expect(location.etaMinutes, 12);
    });

    test('keeps an explicitly supplied realtime ETA authoritative', () {
      final location = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.toIso8601String(),
        'etaMinutes': 9,
      }, fallbackEtaMinutes: 12);

      expect(location.etaMinutes, 9);
    });

    test('freshness rejects stale and future-dated locations', () {
      final fresh = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      });
      final stale = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now
            .subtract(const Duration(minutes: 2, seconds: 1))
            .toIso8601String(),
      });
      final future = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.add(const Duration(seconds: 1)).toIso8601String(),
      });

      expect(fresh.isFreshAt(now), isTrue);
      expect(stale.isFreshAt(now), isFalse);
      expect(future.isFreshAt(now), isFalse);
    });

    test('timestamp ordering prevents the location stream moving backward', () {
      final later = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.toIso8601String(),
      });
      final earlier = WorkerLocation.fromJson({
        'lat': 13,
        'lng': 80,
        'timestamp': now.subtract(const Duration(seconds: 1)).toIso8601String(),
      });

      expect(later.isAtLeastAsRecentAs(null), isTrue);
      expect(earlier.isAtLeastAsRecentAs(later.timestamp), isFalse);
      expect(later.isAtLeastAsRecentAs(later.timestamp), isTrue);
    });
  });
}
