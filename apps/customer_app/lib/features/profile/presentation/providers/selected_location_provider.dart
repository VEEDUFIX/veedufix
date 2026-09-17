import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectedLocation {
  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

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
    _load();
  }

  final Ref ref;

  static const _latKey = 'customer_selected_location_lat';
  static const _lngKey = 'customer_selected_location_lng';
  static const _labelKey = 'customer_selected_location_label';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) {
      return;
    }
    state = SelectedLocation(
      latitude: lat,
      longitude: lng,
      label: prefs.getString(_labelKey),
    );
  }

  Future<void> setLocation({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    final next = SelectedLocation(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, latitude);
    await prefs.setDouble(_lngKey, longitude);
    final value = label?.trim() ?? '';
    if (value.isEmpty) {
      await prefs.remove(_labelKey);
    } else {
      await prefs.setString(_labelKey, value);
    }
  }
}
