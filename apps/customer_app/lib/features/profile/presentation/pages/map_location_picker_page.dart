import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({super.key, this.initialPosition});

  /// If provided, the map starts here. Otherwise defaults to Kochi.
  final LatLng? initialPosition;

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage>
    with SingleTickerProviderStateMixin {
  static const _defaultCenter = LatLng(10.0261, 76.3125); // Kochi, Kerala
  final AppEnvironment _environment = AppEnvironment.fromDartDefines();

  late LatLng _currentCenter;
  bool _isDragging = false;
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  bool _hasLocationPermission = false;
  String? _locationLabel;
  String? _autocompleteSessionToken;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Completer<GoogleMapController> _mapController = Completer();
  late AnimationController _pinBounce;
  late Animation<double> _pinOffset;
  Timer? _labelDebounce;
  Timer? _suggestionDebounce;
  List<_LocationSuggestion> _suggestions = <_LocationSuggestion>[];

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition ?? _defaultCenter;
    _pinBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _pinOffset = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _pinBounce, curve: Curves.easeOut),
    );
    _refreshLocationLabel(debounced: false);
  }

  @override
  void dispose() {
    _labelDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pinBounce.dispose();
    super.dispose();
  }

  Future<void> _animateTo(LatLng target) async {
    setState(() => _currentCenter = target);
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    }
    _refreshLocationLabel();
  }

  Future<String?> _resolveLocationLabel(LatLng target) async {
    if (_environment.googleMapsApiKey.isEmpty) {
      return null;
    }

    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '${target.latitude},${target.longitude}',
          'key': _environment.googleMapsApiKey,
        },
      );
      final payload = response.data ?? <String, dynamic>{};
      if (payload['status']?.toString() != 'OK') {
        return null;
      }
      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        return null;
      }
      final first = results.first;
      if (first is Map) {
        final formatted = first['formatted_address']?.toString().trim();
        if (formatted != null && formatted.isNotEmpty) {
          return formatted;
        }
      }
    } catch (_) {
      // Best-effort label only.
    }

    return null;
  }

  String _newAutocompleteSessionToken() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random.secure();
    return List.generate(20, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  Future<List<_LocationSuggestion>> _fetchAutocompleteSuggestions(String query) async {
    if (_environment.googleMapsApiKey.isEmpty) {
      return const <_LocationSuggestion>[];
    }

    _autocompleteSessionToken ??= _newAutocompleteSessionToken();

    try {
      final response = await Dio().post<Map<String, dynamic>>(
        'https://places.googleapis.com/v1/places:autocomplete',
        data: {
          'input': query,
          'regionCode': 'in',
          'languageCode': 'en-IN',
          'includeQueryPredictions': false,
          'sessionToken': _autocompleteSessionToken,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': _environment.googleMapsApiKey,
            'X-Goog-FieldMask':
                'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
          },
        ),
      );

      final payload = response.data ?? <String, dynamic>{};
      final suggestions = payload['suggestions'];
      if (suggestions is! List) {
        return const <_LocationSuggestion>[];
      }

      return suggestions
          .whereType<Map>()
          .map((suggestion) {
            final placePrediction = suggestion['placePrediction'];
            if (placePrediction is! Map) {
              return null;
            }
            final placeId = placePrediction['placeId']?.toString().trim();
            final text = placePrediction['text'];
            final structured = placePrediction['structuredFormat'];
            final label = _predictionText(text) ?? _predictionText(structured) ?? placeId;
            if (placeId == null || placeId.isEmpty || label == null || label.isEmpty) {
              return null;
            }
            final secondary = _predictionSecondary(structured);
            return _LocationSuggestion(
              placeId: placeId,
              label: label,
              secondaryLabel: secondary,
            );
          })
          .whereType<_LocationSuggestion>()
          .toList(growable: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Autocomplete failed: $error')),
        );
      }
      return const <_LocationSuggestion>[];
    }
  }

  Future<void> _applySuggestion(_LocationSuggestion suggestion) async {
    _suggestionDebounce?.cancel();
    _autocompleteSessionToken = null;
    _searchController.text = suggestion.label;
    _searchController.selection = TextSelection.collapsed(offset: suggestion.label.length);
    if (mounted) {
      setState(() {
        _suggestions = const <_LocationSuggestion>[];
      });
    }

    if (_environment.googleMapsApiKey.isEmpty) {
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'place_id': suggestion.placeId,
          'key': _environment.googleMapsApiKey,
        },
      );
      final payload = response.data ?? <String, dynamic>{};
      if (payload['status']?.toString() != 'OK') {
        final message = payload['error_message']?.toString();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message?.isNotEmpty == true
                  ? 'Search failed: $message'
                  : 'Could not resolve this place.',
            ),
          ),
        );
        return;
      }

      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        return;
      }

      final first = results.first;
      if (first is! Map) return;
      final geometry = first['geometry'];
      final location = geometry is Map ? geometry['location'] : null;
      final lat = double.tryParse(location is Map ? location['lat']?.toString() ?? '' : '');
      final lon = double.tryParse(location is Map ? location['lng']?.toString() ?? '' : '');
      if (lat == null || lon == null) {
        return;
      }

      final formattedAddress = first['formatted_address']?.toString().trim();
      await _animateTo(LatLng(lat, lon));
      if (formattedAddress != null && formattedAddress.isNotEmpty && mounted) {
        setState(() => _locationLabel = formattedAddress);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _refreshLocationLabel({bool debounced = true}) {
    _labelDebounce?.cancel();
    if (!debounced) {
      unawaited(_updateLocationLabel());
      return;
    }
    _labelDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_updateLocationLabel());
    });
  }

  Future<void> _updateLocationLabel() async {
    final label = await _resolveLocationLabel(_currentCenter);
    if (!mounted) {
      return;
    }
    setState(() {
      _locationLabel = label;
    });
  }

  String? _predictionText(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is Map) {
      final map = value.cast<String, dynamic>();
      final candidates = [
        map['text'],
        map['mainText'] is Map ? (map['mainText'] as Map)['text'] : null,
        map['secondaryText'] is Map ? (map['secondaryText'] as Map)['text'] : null,
      ];
      for (final candidate in candidates) {
        final text = _predictionText(candidate);
        if (text != null) {
          return text;
        }
      }
    }
    return null;
  }

  String? _predictionSecondary(dynamic structuredFormat) {
    if (structuredFormat is! Map) {
      return null;
    }
    final map = structuredFormat.cast<String, dynamic>();
    final secondary = map['secondaryText'];
    return _predictionText(secondary);
  }

  Future<void> _centerOnCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location services to use your current position.')),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to use your current position.')),
        );
        return;
      }

      if (mounted) {
        setState(() => _hasLocationPermission = true);
      }

      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      await _animateTo(LatLng(pos.latitude, pos.longitude));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $error')),
      );
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isSearching) return;

    if (_environment.googleMapsApiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set GOOGLE_MAPS_API_KEY to enable location search.'),
        ),
      );
      return;
    }

    _autocompleteSessionToken = null;
    setState(() => _isSearching = true);
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': query,
          'key': _environment.googleMapsApiKey,
        },
      );
      final payload = response.data ?? <String, dynamic>{};
      final status = payload['status']?.toString() ?? 'UNKNOWN_ERROR';
      if (status != 'OK') {
        if (!mounted) return;
        final message = payload['error_message']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message?.isNotEmpty == true
                  ? 'Search failed: $message'
                  : status == 'ZERO_RESULTS'
                      ? 'No matching location found.'
                      : 'Search failed: $status',
            ),
          ),
        );
        return;
      }

      final results = payload['results'];
      if (results is! List || results.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching location found.')),
        );
        return;
      }

      final first = results.first;
      if (first is! Map) return;
      final geometry = first['geometry'];
      final location = geometry is Map ? geometry['location'] : null;
      final lat = double.tryParse(location is Map ? location['lat']?.toString() ?? '' : '');
      final lon = double.tryParse(location is Map ? location['lng']?.toString() ?? '' : '');
      if (lat == null || lon == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read location coordinates.')),
        );
        return;
      }

      await _animateTo(LatLng(lat, lon));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    _suggestionDebounce?.cancel();
    final query = value.trim();

    if (query.isEmpty) {
      _autocompleteSessionToken = null;
      if (mounted) {
        setState(() {
          _suggestions = const <_LocationSuggestion>[];
          _isLoadingSuggestions = false;
        });
      }
      return;
    }

    _suggestionDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) {
        return;
      }
      if (query.length < 2 || _isSearching) {
        setState(() => _isLoadingSuggestions = false);
        return;
      }

      setState(() => _isLoadingSuggestions = true);
      final suggestions = await _fetchAutocompleteSuggestions(query);
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestions = suggestions;
        _isLoadingSuggestions = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 16,
            ),
            onMapCreated: (controller) {
              if (!_mapController.isCompleted) {
                _mapController.complete(controller);
              }
            },
            onCameraMoveStarted: () {
              setState(() => _isDragging = true);
              _pinBounce.forward();
            },
            onCameraMove: (pos) {
              _currentCenter = pos.target;
            },
            onCameraIdle: () {
              setState(() => _isDragging = false);
              _pinBounce.reverse();
              _refreshLocationLabel();
            },
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Fixed center pin ────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36), // offset so pin base is at center
              child: AnimatedBuilder(
                animation: _pinOffset,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _pinOffset.value),
                    child: child,
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 48,
                      color: cs.primary,
                      shadows: [
                        Shadow(
                          color: cs.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    // Pin shadow
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isDragging ? 8 : 4,
                      height: _isDragging ? 8 : 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: _isDragging ? 0.2 : 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search bar ──────────────────────────────────────────────
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Row(
                children: [
                  TapScale(
                    onTap: () => context.pop(),
                    child: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _searchLocation(),
                      decoration: InputDecoration(
                        hintText: 'Search for a location...',
                        hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  TapScale(
                    onTap: _isSearching ? null : _searchLocation,
                    child: _isSearching
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          )
                        : Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          if (_suggestions.isNotEmpty || _isLoadingSuggestions)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 76,
              left: 16,
              right: 16,
              child: Material(
                color: cs.surface,
                elevation: 10,
                borderRadius: BorderRadius.circular(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: _isLoadingSuggestions
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.place_rounded, color: cs.primary),
                              title: Text(suggestion.label),
                              subtitle: suggestion.secondaryLabel == null
                                  ? null
                                  : Text(suggestion.secondaryLabel!),
                              onTap: () => _applySuggestion(suggestion),
                            );
                          },
                        ),
                ),
              ),
            ),

          // ── My location FAB ─────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 200,
            child: TapScale(
              onTap: () async {
                await _centerOnCurrentLocation();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  boxShadow: AbzioTheme.eliteShadow,
                ),
                child: Icon(Icons.my_location_rounded, color: cs.primary),
              ),
            ),
          ),

          // ── Bottom confirm card ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.paddingOf(context).bottom + 20,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pin_drop_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected Location',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _locationLabel?.isNotEmpty == true
                          ? _locationLabel!
                          : '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                      key: ValueKey('${_currentCenter.latitude}_${_currentCenter.longitude}'),
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  TapScale(
                    onTap: () => context.pop(
                      MapLocationSelection(
                        location: _currentCenter,
                        label: _locationLabel,
                      ),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                        boxShadow: AbzioTheme.eliteShadow,
                      ),
                      child: Center(
                        child: Text(
                          'Confirm Location',
                          style: tt.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSuggestion {
  const _LocationSuggestion({
    required this.placeId,
    required this.label,
    this.secondaryLabel,
  });

  final String placeId;
  final String label;
  final String? secondaryLabel;
}

class MapLocationSelection {
  const MapLocationSelection({
    required this.location,
    this.label,
  });

  final LatLng location;
  final String? label;

  double get latitude => location.latitude;

  double get longitude => location.longitude;
}
