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
    unawaited(_loadFromStats());
  }

  final Ref _ref;

  Future<void> _loadFromStats() async {
    try {
      final stats = await _ref.read(workerDashboardStatsProvider.future);
      if (mounted) state = AsyncValue.data(stats.isAvailable);
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous == null) {
      state = const AsyncValue.loading();
    } else {
      state = const AsyncLoading<bool>().copyWithPrevious(
        AsyncData<bool>(previous),
      );
    }
    await _loadFromStats();
  }

  Future<void> toggle(bool value) async {
    if (state.isLoading) return;
    final previous = state.valueOrNull ?? false;
    state = const AsyncLoading<bool>().copyWithPrevious(
      AsyncData<bool>(value),
    );
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.patch(
        '/worker/availability',
        data: {'isAvailable': value},
      );
      if (mounted) {
        state = AsyncValue.data(value);
        _ref.invalidate(workerDashboardStatsProvider);
      }
    } catch (e) {
      if (mounted) state = AsyncValue.data(previous);
      rethrow;
    }
  }
}

// ─── Location broadcaster (active job) ─────────────────────────────────────

final locationBroadcasterProvider =
    StateNotifierProvider<_LocationBroadcaster, void>((ref) {
  final broadcaster = _LocationBroadcaster(ref);
  ref.listen<JobExecutionState>(
    jobExecutionProvider,
    (_, __) => broadcaster.onExecutionChanged(),
  );
  return broadcaster;
});

class _LocationBroadcaster extends StateNotifier<void> {
  _LocationBroadcaster(this._ref) : super(null);

  final Ref _ref;
  Timer? _timer;
  String? _activeBookingId;
  bool _isBroadcasting = false;

  void start(String bookingId) {
    if (_activeBookingId == bookingId) {
      return;
    }
    stop();
    _activeBookingId = bookingId;
    _syncWithJobState();
  }

  void onExecutionChanged() => _syncWithJobState();

  void stop() {
    _timer?.cancel();
    _timer = null;
    _activeBookingId = null;
  }

  void _syncWithJobState() {
    final execution = _ref.read(jobExecutionProvider);
    final bookingId = _activeBookingId;
    final hasActiveBooking = bookingId != null &&
        execution.hasBooking &&
        execution.booking!.bookingId == bookingId;
    final shouldTrack = hasActiveBooking &&
        execution.summary == null &&
        execution.currentStep >= 2 &&
        execution.currentStep < 7;

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
    if (_isBroadcasting) {
      return;
    }
    final bookingId = _activeBookingId;
    if (bookingId == null) {
      return;
    }
    _isBroadcasting = true;
    try {
      final execution = _ref.read(jobExecutionProvider);
      final hasActiveBooking =
          execution.hasBooking && execution.booking!.bookingId == bookingId;
      final shouldTrack = hasActiveBooking &&
          execution.summary == null &&
          execution.currentStep >= 2 &&
          execution.currentStep < 7;
      if (!shouldTrack) {
        _timer?.cancel();
        _timer = null;
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final latestExecution = _ref.read(jobExecutionProvider);
      if (_activeBookingId != bookingId ||
          !latestExecution.hasBooking ||
          latestExecution.booking!.bookingId != bookingId ||
          latestExecution.summary != null ||
          latestExecution.currentStep < 2 ||
          latestExecution.currentStep >= 7) {
        return;
      }
      final realtime = _ref.read(realtimeServiceProvider);
      realtime.sendLocationUpdate(pos.latitude, pos.longitude);
    } catch (_) {
    } finally {
      _isBroadcasting = false;
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
