import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

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
