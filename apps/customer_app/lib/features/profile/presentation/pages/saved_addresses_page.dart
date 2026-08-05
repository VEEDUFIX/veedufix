import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/saved_addresses_api.dart';
import 'map_location_picker_page.dart';

class SavedAddressesPage extends ConsumerStatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  ConsumerState<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends ConsumerState<SavedAddressesPage> {
  late final SavedAddressesApi _api;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<SavedAddressItem> _addresses = <SavedAddressItem>[];

  @override
  void initState() {
    super.initState();
    _api = SavedAddressesApi(ref.read(apiClientProvider).dio);
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final addresses = await _api.listAddresses();
      if (!mounted) {
        return;
      }
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error is DioException ? _errorMessageFromDio(error) : error.toString();
      });
    }
  }

  Future<void> _saveAddress({SavedAddressItem? existing}) async {
    final result = await showModalBottomSheet<_SavedAddressDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavedAddressEditorSheet(existing: existing),
    );

    if (result == null) {
      return;
    }

    try {
      final serviceable = await _api.isServiceablePincode(
        pincode: result.pincode,
        city: result.city,
      );
      if (!serviceable) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We don't currently serve this area yet — we're expanding soon!"),
          ),
        );
        return;
      }

      setState(() {
        _isSaving = true;
      });

      if (existing == null) {
        await _api.createAddress(result.toJson());
      } else {
        await _api.updateAddress(existing.id, result.toJson());
      }
      await _loadAddresses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save address: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteAddress(SavedAddressItem address) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove ${address.label}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _api.deleteAddress(address.id);
      await _loadAddresses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete address: $error')),
      );
    }
  }

  Future<void> _setDefaultAddress(SavedAddressItem address) async {
    try {
      await _api.setDefaultAddress(address.id);
      await _loadAddresses();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to set default: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultAddress = _addresses.firstWhere(
      (address) => address.isDefault,
      orElse: () => _addresses.isNotEmpty ? _addresses.first : const SavedAddressItem(
        id: '',
        label: '',
        addressLine1: '',
        city: '',
        pincode: '',
        lat: 0,
        lng: 0,
        isDefault: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved addresses'),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : () => _saveAddress(),
            icon: const Icon(Icons.add_location_alt_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () => _saveAddress(),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAddresses,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_addresses.isNotEmpty)
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checkout address',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        defaultAddress.displayAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _StatusPill(
                            label: defaultAddress.isDefault ? 'Default' : 'Selected',
                            icon: Icons.check_circle_rounded,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push('/bookings'),
                            child: const Text('Use in bookings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(_errorMessage!),
                ),
              )
            else if (_addresses.isEmpty)
              const PremiumEmptyState(
                icon: Icons.home_outlined,
                title: 'No saved addresses yet',
                subtitle: 'Add Home, Work, or any frequent service location so checkout stays quick.',
              )
            else
              ..._addresses.map(
                (address) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AddressCard(
                    address: address,
                    onEdit: () => _saveAddress(existing: address),
                    onDelete: () => _deleteAddress(address),
                    onMakeDefault: address.isDefault ? null : () => _setDefaultAddress(address),
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onEdit,
    required this.onDelete,
    required this.onMakeDefault,
  });

  final SavedAddressItem address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMakeDefault;

  Future<void> _openInMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${address.lat},${address.lng}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (address.isDefault) const _StatusPill(label: 'Default', icon: Icons.star_rounded),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address.displayAddress,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat ${address.lat.toStringAsFixed(5)} • Lng ${address.lng.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openInMaps(context),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Open in Maps'),
                ),
                if (onMakeDefault != null)
                  FilledButton.tonalIcon(
                    onPressed: onMakeDefault,
                    icon: const Icon(Icons.star_outline_rounded),
                    label: const Text('Make default'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
}

class _SavedAddressDraft {
  const _SavedAddressDraft({
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.pincode,
    required this.lat,
    required this.lng,
    required this.isDefault,
    this.addressLine2,
    this.landmark,
  });

  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? landmark;
  final String city;
  final String pincode;
  final double lat;
  final double lng;
  final bool isDefault;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'lat': lat,
      'lng': lng,
      'isDefault': isDefault,
    };
  }
}

class _SavedAddressEditorSheet extends StatefulWidget {
  const _SavedAddressEditorSheet({this.existing});

  final SavedAddressItem? existing;

  @override
  State<_SavedAddressEditorSheet> createState() => _SavedAddressEditorSheetState();
}

class _SavedAddressEditorSheetState extends State<_SavedAddressEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _addressLine1Controller;
  late final TextEditingController _addressLine2Controller;
  late final TextEditingController _landmarkController;
  late final TextEditingController _cityController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _labelController = TextEditingController(text: existing?.label ?? 'Home');
    _addressLine1Controller = TextEditingController(text: existing?.addressLine1 ?? '');
    _addressLine2Controller = TextEditingController(text: existing?.addressLine2 ?? '');
    _landmarkController = TextEditingController(text: existing?.landmark ?? '');
    _cityController = TextEditingController(text: existing?.city ?? '');
    _pincodeController = TextEditingController(text: existing?.pincode ?? '');
    _latController = TextEditingController(text: existing?.lat.toString() ?? '');
    _lngController = TextEditingController(text: existing?.lng.toString() ?? '');
    _isDefault = existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
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

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final picked = await context.push<MapLocationSelection>(
        '/map-picker?lat=${pos.latitude}&lng=${pos.longitude}',
      );
      if (picked == null || !mounted) return;

      setState(() {
        _latController.text = picked.latitude.toStringAsFixed(6);
        _lngController.text = picked.longitude.toStringAsFixed(6);
        if ((picked.label ?? '').trim().isNotEmpty && _addressLine1Controller.text.trim().isEmpty) {
          _addressLine1Controller.text = picked.label!.trim();
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to use current location: $error')),
      );
    }
  }

  Future<void> _pickOnMap() async {
    try {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      final initial = (lat != null && lng != null)
          ? LatLng(lat, lng)
          : const LatLng(10.0261, 76.3125);

      final picked = await context.push<MapLocationSelection>(
        '/map-picker?lat=${initial.latitude}&lng=${initial.longitude}',
      );
      if (picked == null || !mounted) return;

      setState(() {
        _latController.text = picked.latitude.toStringAsFixed(6);
        _lngController.text = picked.longitude.toStringAsFixed(6);
        if ((picked.label ?? '').trim().isNotEmpty && _addressLine1Controller.text.trim().isEmpty) {
          _addressLine1Controller.text = picked.label!.trim();
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open map picker: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null ? 'Add saved address' : 'Edit saved address',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                _InputField(controller: _labelController, label: 'Label', validator: _requiredValidator),
                _InputField(controller: _addressLine1Controller, label: 'Address line 1', validator: _requiredValidator),
                _InputField(controller: _addressLine2Controller, label: 'Address line 2', optional: true),
                _InputField(controller: _landmarkController, label: 'Landmark', optional: true),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(controller: _cityController, label: 'City', validator: _requiredValidator),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        controller: _pincodeController,
                        label: 'Pincode *',
                        validator: _pincodeValidator,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: _InputField(
                        controller: _latController,
                        label: 'Latitude',
                        validator: _coordinateValidator(-90, 90),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InputField(
                        controller: _lngController,
                        label: 'Longitude',
                        validator: _coordinateValidator(-180, 180),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _useCurrentLocation,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Use current location'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _pickOnMap,
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Pick on map'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isDefault,
                  onChanged: (value) => setState(() => _isDefault = value),
                  title: const Text('Set as default'),
                  subtitle: const Text('Only one address can be the default at a time.'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final draft = _SavedAddressDraft(
      label: _labelController.text.trim(),
      addressLine1: _addressLine1Controller.text.trim(),
      addressLine2: _trimmedOrNull(_addressLine2Controller.text),
      landmark: _trimmedOrNull(_landmarkController.text),
      city: _cityController.text.trim(),
      pincode: _pincodeController.text.trim(),
      lat: double.parse(_latController.text.trim()),
      lng: double.parse(_lngController.text.trim()),
      isDefault: _isDefault,
    );

    Navigator.of(context).pop(draft);
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.optional = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        validator: validator ?? (optional ? null : _requiredValidator),
        decoration: InputDecoration(
          labelText: label,
          hintText: optional ? 'Optional' : null,
        ),
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'This field is required';
  }
  return null;
}

String? _pincodeValidator(String? value) {
  if (value == null || !RegExp(r'^[1-9][0-9]{5}$').hasMatch(value.trim())) {
    return 'A valid 6-digit pincode is required';
  }
  return null;
}

String? Function(String?) _coordinateValidator(num min, num max) {
  return (value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed < min || parsed > max) {
      return 'Value must be between $min and $max';
    }
    return null;
  };
}

String? _trimmedOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _errorMessageFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
  }
  return error.message ?? 'Request failed';
}
