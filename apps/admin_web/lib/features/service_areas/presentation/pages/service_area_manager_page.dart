import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ServiceAreaManagerPage extends ConsumerStatefulWidget {
  const ServiceAreaManagerPage({super.key});

  @override
  ConsumerState<ServiceAreaManagerPage> createState() => _ServiceAreaManagerPageState();
}

class _ServiceAreaManagerPageState extends ConsumerState<ServiceAreaManagerPage> {
  late final _ServiceAreaAdminApi _api;
  late Future<_ServiceAreaSnapshot> _snapshotFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _api = _ServiceAreaAdminApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _loadSnapshot();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<_ServiceAreaSnapshot> _loadSnapshot() async {
    return _api.fetchSnapshot();
  }

  Future<void> _reload() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<_ServiceAreaRecord> _visibleAreas(_ServiceAreaSnapshot snapshot) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return snapshot.serviceAreas;
    }

    return snapshot.serviceAreas.where((area) {
      return area.name.toLowerCase().contains(query) ||
          area.slug.toLowerCase().contains(query) ||
          area.city.name.toLowerCase().contains(query) ||
          (area.pincode ?? '').contains(query) ||
          (area.pincodeRangeStart ?? '').contains(query) ||
          (area.pincodeRangeEnd ?? '').contains(query);
    }).toList(growable: false);
  }

  Future<void> _createArea(_ServiceAreaSnapshot snapshot) async {
    final payload = await _showEditor(snapshot);
    if (payload == null) {
      return;
    }
    try {
      await _api.createServiceArea(payload);
      await _reload();
      await _showMessage('Service area created');
    } catch (error) {
      await _showMessage('Unable to create service area: $error');
    }
  }

  Future<void> _editArea(_ServiceAreaSnapshot snapshot, _ServiceAreaRecord area) async {
    final payload = await _showEditor(snapshot, existing: area);
    if (payload == null) {
      return;
    }
    try {
      await _api.updateServiceArea(area.id, payload);
      await _reload();
      await _showMessage('Service area updated');
    } catch (error) {
      await _showMessage('Unable to update service area: $error');
    }
  }

  Future<void> _deleteArea(_ServiceAreaRecord area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete service area?'),
          content: Text('Remove ${area.name} (${area.city.name}) from the active configuration?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _api.deleteServiceArea(area.id);
      await _reload();
      await _showMessage('Service area deleted');
    } catch (error) {
      await _showMessage('Unable to delete service area: $error');
    }
  }

  Future<void> _toggleAreaActive(_ServiceAreaRecord area, bool isActive) async {
    try {
      await _api.updateServiceArea(area.id, {'isActive': isActive});
      await _reload();
      await _showMessage(isActive ? 'Service area activated' : 'Service area paused');
    } catch (error) {
      await _showMessage('Unable to update service area: $error');
    }
  }

  Future<Map<String, dynamic>?> _showEditor(
    _ServiceAreaSnapshot snapshot, {
    _ServiceAreaRecord? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final exactPincodeController = TextEditingController(text: existing?.pincode ?? '');
    final rangeStartController = TextEditingController(text: existing?.pincodeRangeStart ?? '');
    final rangeEndController = TextEditingController(text: existing?.pincodeRangeEnd ?? '');
    final cityId = ValueNotifier<String>(existing?.cityId ?? (snapshot.cities.isNotEmpty ? snapshot.cities.first.id : ''));
    final isActive = ValueNotifier<bool>(existing?.isActive ?? true);
    final formError = ValueNotifier<String?>(null);

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(existing == null ? 'Create service area' : 'Edit service area'),
            content: SizedBox(
              width: 720,
              child: StatefulBuilder(
                builder: (context, setState) {
                  final hasCities = snapshot.cities.isNotEmpty;
                  return SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: cityId.value.isEmpty ? null : cityId.value,
                            decoration: const InputDecoration(
                              labelText: 'City *',
                              border: OutlineInputBorder(),
                            ),
                            items: snapshot.cities
                                .map(
                                  (city) => DropdownMenuItem<String>(
                                    value: city.id,
                                    child: Text('${city.name} (${city.slug})'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: hasCities
                                ? (value) {
                                    if (value == null) return;
                                    setState(() {
                                      cityId.value = value;
                                    });
                                  }
                                : null,
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Choose a city';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Area name *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'Enter a name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: slugController,
                            decoration: const InputDecoration(
                              labelText: 'Slug',
                              helperText: 'Optional. Auto-generated from the name if left blank.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: exactPincodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Exact pincode',
                                    helperText: 'Optional if you are using a pincode range.',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: rangeStartController,
                                  decoration: const InputDecoration(
                                    labelText: 'Range start',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: rangeEndController,
                                  decoration: const InputDecoration(
                                    labelText: 'Range end',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String?>(
                            valueListenable: formError,
                            builder: (context, error, _) {
                              if (error == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            subtitle: const Text('Only active areas can accept bookings.'),
                            value: isActive.value,
                            onChanged: (value) {
                              setState(() {
                                isActive.value = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final slug = slugController.text.trim();
                  final exact = exactPincodeController.text.trim();
                  final start = rangeStartController.text.trim();
                  final end = rangeEndController.text.trim();

                  String? error;
                  final exactValid = exact.isEmpty || RegExp(r'^[1-9][0-9]{5}$').hasMatch(exact);
                  final startValid = start.isEmpty || RegExp(r'^[1-9][0-9]{5}$').hasMatch(start);
                  final endValid = end.isEmpty || RegExp(r'^[1-9][0-9]{5}$').hasMatch(end);

                  if (cityId.value.isEmpty) {
                    error = 'Choose a city';
                  } else if (name.isEmpty) {
                    error = 'Enter a name';
                  } else if (!exactValid || !startValid || !endValid) {
                    error = 'A valid 6-digit pincode is required';
                  } else if (exact.isEmpty && (start.isEmpty || end.isEmpty)) {
                    error = 'Enter either an exact pincode or both range fields';
                  } else if (start.isNotEmpty && end.isNotEmpty && int.parse(start) > int.parse(end)) {
                    error = 'Range start must be less than or equal to range end';
                  }

                  if (error != null) {
                    formError.value = error;
                    return;
                  }

                  final payload = <String, dynamic>{
                    'cityId': cityId.value,
                    'name': name,
                    'isActive': isActive.value,
                  };
                  if (slug.isNotEmpty) {
                    payload['slug'] = slug;
                  }
                  if (exact.isNotEmpty) {
                    payload['pincode'] = exact;
                  }
                  if (start.isNotEmpty) {
                    payload['pincodeRangeStart'] = start;
                  }
                  if (end.isNotEmpty) {
                    payload['pincodeRangeEnd'] = end;
                  }
                  Navigator.of(dialogContext).pop(payload);
                },
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      );
    } finally {
      nameController.dispose();
      slugController.dispose();
      exactPincodeController.dispose();
      rangeStartController.dispose();
      rangeEndController.dispose();
      cityId.dispose();
      isActive.dispose();
      formError.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<_ServiceAreaSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;
          final visibleAreas = data == null ? const <_ServiceAreaRecord>[] : _visibleAreas(data);

          return SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 20 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isCompact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Service Areas',
                            style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Control where the marketplace is open and how far each zone reaches.',
                            style: GoogleFonts.inter(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: loading || data == null ? null : () => _createArea(data),
                            icon: const Icon(Icons.add_location_alt_rounded),
                            label: const Text('Add service area'),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Service Areas',
                                style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Control where the marketplace is open and how far each zone reaches.',
                                style: GoogleFonts.inter(color: Colors.black54, fontSize: 16),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            onPressed: loading || data == null ? null : () => _createArea(data),
                            icon: const Icon(Icons.add_location_alt_rounded),
                            label: const Text('Add service area'),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),
                if (loading)
                  const Center(child: CircularProgressIndicator())
                else if (data != null) ...[
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      _StatCard(label: 'Areas', value: '${data.serviceAreas.length}', icon: Icons.place_rounded, color: const Color(0xFF2563EB)),
                      _StatCard(label: 'Active', value: '${data.activeCount}', icon: Icons.check_circle_rounded, color: const Color(0xFF0F766E)),
                      _StatCard(label: 'Cities', value: '${data.cities.length}', icon: Icons.location_city_rounded, color: const Color(0xFF8B5CF6)),
                      _StatCard(label: 'Range rules', value: '${data.rangeCount}', icon: Icons.alt_route_rounded, color: const Color(0xFFF59E0B)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 900;
                      final filterRow = narrow
                          ? Column(
                              children: [
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) => setState(() => _searchQuery = value),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.search_rounded),
                                    hintText: 'Search by area, city, or pincode',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) => setState(() => _searchQuery = value),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search_rounded),
                                      hintText: 'Search by area, city, or pincode',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                  label: const Text('Clear'),
                                ),
                              ],
                            );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          filterRow,
                          const SizedBox(height: 20),
                          ...visibleAreas.map(
                            (area) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ServiceAreaTile(
                                area: area,
                                onEdit: () => _editArea(data, area),
                                onDelete: () => _deleteArea(area),
                                onToggleActive: (value) => _toggleAreaActive(area, value),
                              ),
                            ),
                          ),
                          if (visibleAreas.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Text(
                                  'No matching service areas',
                                  style: GoogleFonts.inter(color: Colors.black54),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServiceAreaTile extends StatelessWidget {
  const _ServiceAreaTile({
    required this.area,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final _ServiceAreaRecord area;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final coverage = area.pincode != null
        ? 'Exact pincode ${area.pincode}'
        : 'Range ${area.pincodeRangeStart ?? 'n/a'} - ${area.pincodeRangeEnd ?? 'n/a'}';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: area.isActive ? const Color(0xFF0F766E).withValues(alpha: 0.12) : const Color(0xFF94A3B8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                area.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                color: area.isActive ? const Color(0xFF0F766E) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          area.name,
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Switch.adaptive(value: area.isActive, onChanged: onToggleActive),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${area.city.name} • ${area.slug}',
                    style: GoogleFonts.inter(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Chip(label: coverage, icon: Icons.route_rounded),
                      _Chip(label: area.isActive ? 'Active' : 'Paused', icon: area.isActive ? Icons.check_rounded : Icons.pause_rounded),
                      if (area.pincodeRangeStart != null && area.pincodeRangeEnd != null)
                        _Chip(label: 'Range mode', icon: Icons.alt_route_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.black54)),
              Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceAreaAdminApi {
  _ServiceAreaAdminApi(this._dio);

  final Dio _dio;

  Future<_ServiceAreaSnapshot> fetchSnapshot() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/service-areas');
    final data = response.data ?? <String, dynamic>{};
    final cities = (data['cities'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_ServiceAreaCity.fromJson)
        .toList(growable: false);
    final serviceAreas = (data['serviceAreas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((json) => _ServiceAreaRecord.fromJson(json, cities))
        .toList(growable: false);
    return _ServiceAreaSnapshot(cities: cities, serviceAreas: serviceAreas);
  }

  Future<void> createServiceArea(Map<String, dynamic> data) async {
    await _dio.post('/admin/service-areas', data: data);
  }

  Future<void> updateServiceArea(String id, Map<String, dynamic> data) async {
    await _dio.patch('/admin/service-areas/$id', data: data);
  }

  Future<void> deleteServiceArea(String id) async {
    await _dio.delete('/admin/service-areas/$id', data: const {});
  }
}

class _ServiceAreaSnapshot {
  const _ServiceAreaSnapshot({
    required this.cities,
    required this.serviceAreas,
  });

  final List<_ServiceAreaCity> cities;
  final List<_ServiceAreaRecord> serviceAreas;

  int get activeCount => serviceAreas.where((area) => area.isActive).length;
  int get rangeCount => serviceAreas.where((area) => area.pincodeRangeStart != null && area.pincodeRangeEnd != null).length;
}

class _ServiceAreaCity {
  const _ServiceAreaCity({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory _ServiceAreaCity.fromJson(Map<String, dynamic> json) {
    return _ServiceAreaCity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
    );
  }
}

class _ServiceAreaRecord {
  const _ServiceAreaRecord({
    required this.id,
    required this.cityId,
    required this.city,
    required this.name,
    required this.slug,
    required this.pincode,
    required this.pincodeRangeStart,
    required this.pincodeRangeEnd,
    required this.isActive,
  });

  final String id;
  final String cityId;
  final _ServiceAreaCity city;
  final String name;
  final String slug;
  final String? pincode;
  final String? pincodeRangeStart;
  final String? pincodeRangeEnd;
  final bool isActive;

  factory _ServiceAreaRecord.fromJson(
    Map<String, dynamic> json,
    List<_ServiceAreaCity> cities,
  ) {
    final cityId = json['cityId']?.toString() ?? '';
    final city = cities.firstWhere(
      (item) => item.id == cityId,
      orElse: () => _ServiceAreaCity(
        id: cityId,
        name: json['city'] is Map ? (json['city'] as Map)['name']?.toString() ?? '' : '',
        slug: json['city'] is Map ? (json['city'] as Map)['slug']?.toString() ?? '' : '',
      ),
    );

    return _ServiceAreaRecord(
      id: json['id']?.toString() ?? '',
      cityId: cityId,
      city: city,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      pincode: json['pincode']?.toString(),
      pincodeRangeStart: json['pincodeRangeStart']?.toString(),
      pincodeRangeEnd: json['pincodeRangeEnd']?.toString(),
      isActive: json['isActive'] == true,
    );
  }
}
