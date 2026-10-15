import 'package:flutter_test/flutter_test.dart';
import 'package:worker_app/features/worker/presentation/providers/job_execution_provider.dart';

void main() {
  group('JobExecutionState live tracking status', () {
    test('does not report live sharing until a location update succeeds', () {
      const state = JobExecutionState(
        trackingStarted: true,
        trackingConnected: false,
        trackingError: 'Location update failed',
      );

      expect(state.isTracking, isFalse);
      expect(
        state.copyWith(trackingConnected: true, trackingError: null).isTracking,
        isTrue,
      );
    });

    test('reports sharing stopped when the connection is paused', () {
      const connected = JobExecutionState(
        trackingStarted: true,
        trackingConnected: true,
      );

      final paused = connected.copyWith(
        trackingConnected: false,
        trackingError: 'Sharing paused',
      );

      expect(paused.trackingStarted, isTrue);
      expect(paused.isTracking, isFalse);
      expect(paused.trackingError, 'Sharing paused');
    });

    test('offers Settings only for permission or GPS tracking errors', () {
      const permissionError = JobExecutionState(
        trackingError: 'Location permission is required',
        trackingErrorKind: TrackingErrorKind.permission,
      );
      const gpsError = JobExecutionState(
        trackingError: 'Turn on GPS',
        trackingErrorKind: TrackingErrorKind.gps,
      );
      const networkError = JobExecutionState(
        trackingError: 'Connection unavailable',
        trackingErrorKind: TrackingErrorKind.network,
      );
      const backgroundPause = JobExecutionState(
        trackingError: 'Sharing paused',
        trackingErrorKind: TrackingErrorKind.background,
      );

      expect(permissionError.canOpenTrackingSettings, isTrue);
      expect(gpsError.canOpenTrackingSettings, isTrue);
      expect(networkError.canOpenTrackingSettings, isFalse);
      expect(backgroundPause.canOpenTrackingSettings, isFalse);
    });

    test('clearing a tracking error also clears its kind', () {
      const state = JobExecutionState(
        trackingError: 'Connection unavailable',
        trackingErrorKind: TrackingErrorKind.network,
      );

      final cleared = state.copyWith(trackingError: null);

      expect(cleared.trackingError, isNull);
      expect(cleared.trackingErrorKind, isNull);
      expect(cleared.canOpenTrackingSettings, isFalse);
    });
  });
}
