import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import 'job_execution_provider.dart';

// ─── Availability provider ──────────────────────────────────────────────────

final availabilityToggleProvider =
    StateNotifierProvider<_AvailabilityNotifier, AsyncValue<bool>>((ref) {
  return _AvailabilityNotifier(ref);
});

class _AvailabilityNotifier extends StateNotifier<AsyncValue<bool>> {
  _AvailabilityNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadFromStats();
  }

  final Ref _ref;

  void _loadFromStats() {
    final stats = _ref.read(workerDashboardStatsProvider);
    stats.whenData((s) {
      if (mounted) state = AsyncValue.data(s.isAvailable);
    });
  }

  Future<void> toggle(bool value) async {
    final previous = state.valueOrNull ?? true;
    state = AsyncValue.data(value);
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.patch(
        '/worker/availability',
        data: {'isAvailable': value},
      );
      _ref.invalidate(workerDashboardStatsProvider);
    } catch (e) {
      // Revert on failure
      if (mounted) state = AsyncValue.data(previous);
    }
  }
}

// ─── Location broadcaster (active job) ─────────────────────────────────────

final locationBroadcasterProvider =
    StateNotifierProvider<_LocationBroadcaster, void>((ref) {
  return _LocationBroadcaster(ref);
});

class _LocationBroadcaster extends StateNotifier<void> {
  _LocationBroadcaster(this._ref) : super(null);

  final Ref _ref;
  Timer? _timer;
  String? _activeBookingId;

  void start(String bookingId) {
    if (_activeBookingId == bookingId) return;
    stop();
    _activeBookingId = bookingId;
    _syncWithJobState();
    _ref.listen<JobExecutionState>(
      jobExecutionProvider,
      (_, __) => _syncWithJobState(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeBookingId = null;
  }

  void _syncWithJobState() {
    final execution = _ref.read(jobExecutionProvider);
    final bookingId = _activeBookingId;
    final hasActiveBooking =
        bookingId != null && execution.hasBooking && execution.booking!.bookingId == bookingId;
    final shouldTrack = hasActiveBooking && execution.summary == null && execution.currentStep >= 2 && execution.currentStep < 7;

    if (!shouldTrack) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    if (_timer != null) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _broadcast());
    _broadcast();
  }

  Future<void> _broadcast() async {
    try {
      final execution = _ref.read(jobExecutionProvider);
      final bookingId = _activeBookingId;
      final hasActiveBooking =
          bookingId != null && execution.hasBooking && execution.booking!.bookingId == bookingId;
      final shouldTrack = hasActiveBooking && execution.summary == null && execution.currentStep >= 2 && execution.currentStep < 7;
      if (!shouldTrack) {
        _timer?.cancel();
        _timer = null;
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) { return; }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final realtime = _ref.read(realtimeServiceProvider);
      realtime.sendLocationUpdate(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
