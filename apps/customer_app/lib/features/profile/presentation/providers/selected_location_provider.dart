import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedLocation {
  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    this.label,
    this.addressId,
  });

  final double latitude;
  final double longitude;
  final String? label;
  final String? addressId;

  LatLng get latLng => LatLng(latitude, longitude);

  String get title {
    final value = label?.trim() ?? '';
    if (value.isEmpty) {
      return 'Selected location';
    }
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return value;
  }
}

final selectedLocationProvider =
    StateNotifierProvider<SelectedLocationController, SelectedLocation?>(
      SelectedLocationController.new,
    );

class SelectedLocationController extends StateNotifier<SelectedLocation?> {
  SelectedLocationController(this.ref) : super(null) {
    final userId = ref
        .read(authControllerProvider)
        .valueOrNull
        ?.user
        .id;
    _storageScope = _scopeFor(userId);
    ref.listen(
      authControllerProvider.select((auth) => auth.valueOrNull?.user.id),
      (previousUserId, userId) {
        final nextScope = _scopeFor(userId);
        if (nextScope != _storageScope) {
          _storageScope = nextScope;
          if (mounted) {
            state = null;
          }
          unawaited(_load(nextScope));
        }
      },
    );
    unawaited(_load(_storageScope));
  }

  final Ref ref;
  String _storageScope = 'guest';
  int _loadGeneration = 0;

  static String _scopeFor(String? userId) => userId == null
      ? 'guest'
      : Uri.encodeComponent(userId);

  static String _key(String scope, String field) =>
      'customer_selected_location_${scope}_$field';

  Future<void> _load(String scope) async {
    final generation = ++_loadGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          generation != _loadGeneration ||
          scope != _storageScope) {
        return;
      }
      final lat = prefs.getDouble(_key(scope, 'lat'));
      final lng = prefs.getDouble(_key(scope, 'lng'));
      if (lat == null || lng == null) {
        return;
      }
      if (!_isValidCoordinate(lat, lng)) {
        await _removeSavedLocation(prefs, scope);
        return;
      }
      state = SelectedLocation(
        latitude: lat,
        longitude: lng,
        label: prefs.getString(_key(scope, 'label')),
        addressId: prefs.getString(_key(scope, 'addressId')),
      );
    } catch (_) {
      // The last selected location is a convenience; startup can continue without it.
    }
  }

  static bool _isValidCoordinate(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  Future<void> _removeSavedLocation(
    SharedPreferences prefs,
    String scope,
  ) async {
    await prefs.remove(_key(scope, 'lat'));
    await prefs.remove(_key(scope, 'lng'));
    await prefs.remove(_key(scope, 'label'));
    await prefs.remove(_key(scope, 'addressId'));
  }

  Future<void> setLocation({
    required double latitude,
    required double longitude,
    String? label,
    String? addressId,
  }) async {
    if (!_isValidCoordinate(latitude, longitude)) {
      throw ArgumentError('Choose a valid map location.');
    }
    final scope = _storageScope;
    final next = SelectedLocation(
      latitude: latitude,
      longitude: longitude,
      label: label,
      addressId: addressId,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key(scope, 'lat'), latitude);
    await prefs.setDouble(_key(scope, 'lng'), longitude);
    final value = label?.trim() ?? '';
    if (value.isEmpty) {
      await prefs.remove(_key(scope, 'label'));
    } else {
      await prefs.setString(_key(scope, 'label'), value);
    }
    final normalizedAddressId = addressId?.trim() ?? '';
    if (normalizedAddressId.isEmpty) {
      await prefs.remove(_key(scope, 'addressId'));
    } else {
      await prefs.setString(_key(scope, 'addressId'), normalizedAddressId);
    }
    if (mounted && scope == _storageScope) {
      state = next;
    }
  }

  Future<void> clearLocation() async {
    final scope = _storageScope;
    if (mounted) {
      state = null;
    }
    final prefs = await SharedPreferences.getInstance();
    await _removeSavedLocation(prefs, scope);
  }
}
