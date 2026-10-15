import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/admin_image_picker_field.dart';

bool _customAvailabilityHasNoLocations(
        String mode, Set<String> serviceAreaIds) =>
    mode == 'CUSTOM' && serviceAreaIds.isEmpty;

({
  String stateId,
  String districtId,
  String cityId,
  String areaId,
  String pincode,
}) _effectiveCatalogLocationFilters(
  _CatalogSnapshot snapshot, {
  required String stateId,
  required String districtId,
  required String cityId,
  required String areaId,
  required String pincode,
}) {
  final activeAreas = snapshot.serviceAreas
      .where((area) =>
          area.isActive && area.cityIsActive && area.stateId.isNotEmpty)
      .toList(growable: false);
  final stateIds = activeAreas.map((area) => area.stateId).toSet();
  final effectiveStateId =
      stateId == 'all' || stateIds.contains(stateId) ? stateId : 'all';
  final stateAreas = activeAreas.where(
    (area) => effectiveStateId == 'all' || area.stateId == effectiveStateId,
  );
  final districtIds = stateAreas
      .where((area) => area.districtId.isNotEmpty)
      .map((area) => area.districtId)
      .toSet();
  final effectiveDistrictId =
      districtId == 'all' || districtIds.contains(districtId)
          ? districtId
          : 'all';
  final districtAreas = stateAreas.where(
    (area) =>
        effectiveDistrictId == 'all' || area.districtId == effectiveDistrictId,
  );
  final cityIds = districtAreas
      .where((area) => area.cityId.isNotEmpty)
      .map((area) => area.cityId)
      .toSet();
  final effectiveCityId =
      cityId == 'all' || cityIds.contains(cityId) ? cityId : 'all';
  final cityAreas = districtAreas.where(
    (area) => effectiveCityId == 'all' || area.cityId == effectiveCityId,
  );
  final areaIds = cityAreas.map((area) => area.id).toSet();
  final effectiveAreaId =
      areaId == 'all' || areaIds.contains(areaId) ? areaId : 'all';
  final pincodeAreas = cityAreas.where(
    (area) => effectiveAreaId == 'all' || area.id == effectiveAreaId,
  );
  final pincodes = pincodeAreas.expand((area) => area.pincodes).toSet();
  final effectivePincode =
      pincode == 'all' || pincodes.contains(pincode) ? pincode : 'all';

  return (
    stateId: effectiveStateId,
    districtId: effectiveDistrictId,
    cityId: effectiveCityId,
    areaId: effectiveAreaId,
    pincode: effectivePincode,
  );
}

String _variantAvailabilityKey(
  List<_AdminServiceOption> existingVariants,
  int index,
  String name, {
  Iterable<String> allNames = const [],
}) {
  final normalizedName = name.trim().toLowerCase();
  final matchingVariant = existingVariants
      .where((variant) => variant.name.trim().toLowerCase() == normalizedName)
      .firstOrNull;
  final claimedNames =
      allNames.map((value) => value.trim().toLowerCase()).toSet();
  final candidate =
      index < existingVariants.length ? existingVariants[index] : null;
  final variantAtIndex = candidate != null &&
          !claimedNames.contains(candidate.name.trim().toLowerCase())
      ? candidate
      : null;
  final variant = matchingVariant?.id.isNotEmpty == true
      ? matchingVariant
      : variantAtIndex?.id.isNotEmpty == true
          ? variantAtIndex
          : null;
  return variant?.id ?? 'draft:$normalizedName';
}

bool _hasUncoveredCustomVariant(
  String variantsText,
  List<_AdminServiceOption> existingVariants,
  Map<String, String> availabilityModes,
  Map<String, Set<String>> serviceAreaIds,
) {
  final variantNames = variantsText
      .split('\n')
      .map((line) => line.split('|').first.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  return variantNames.asMap().entries.any((entry) {
    final key = _variantAvailabilityKey(
      existingVariants,
      entry.key,
      entry.value,
      allNames: variantNames,
    );
    return availabilityModes[key] == 'CUSTOM' &&
        (serviceAreaIds[key]?.isEmpty ?? true);
  });
}

void _showCustomAvailabilityValidationError(BuildContext context,
    {bool isVariant = false}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        isVariant
            ? 'Choose at least one location for every custom variant.'
            : 'Choose at least one location for custom availability.',
      ),
    ),
  );
}

Widget _buildPublicationControls({
  required BuildContext context,
  required _CatalogSnapshot snapshot,
  required String publicationStatus,
  required DateTime? publishStartsAt,
  required DateTime? publishEndsAt,
  required String availabilityMode,
  required String availabilityKey,
  required Set<String> serviceAreaIds,
  required ValueChanged<String> onPublicationStatusChanged,
  required ValueChanged<DateTime?> onPublishStartsAtChanged,
  required ValueChanged<DateTime?> onPublishEndsAtChanged,
  required ValueChanged<String> onAvailabilityModeChanged,
  required ValueChanged<String> onServiceAreaToggled,
  String? dateError,
}) {
  Future<void> pickDate({required bool isStart}) async {
    final current = isStart ? publishStartsAt : publishEndsAt;
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    if (isStart) {
      onPublishStartsAtChanged(
        DateTime(selected.year, selected.month, selected.day),
      );
    } else {
      onPublishEndsAtChanged(
        DateTime(selected.year, selected.month, selected.day, 23, 59, 59, 999),
      );
    }
  }

  String dateLabel(String label, DateTime? value) => value == null
      ? label
      : '$label · ${MaterialLocalizations.of(context).formatMediumDate(value)}';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Text('Publication & availability',
          style: Theme.of(context).textTheme.titleSmall),
      DropdownButtonFormField<String>(
        initialValue: publicationStatus,
        decoration: const InputDecoration(labelText: 'Publication status'),
        items: const [
          DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
          DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
          DropdownMenuItem(value: 'ARCHIVED', child: Text('Archived')),
        ],
        onChanged: (value) {
          if (value != null) onPublicationStatusChanged(value);
        },
      ),
      const SizedBox(height: 12),
      _AvailabilitySettingsEditor(
        snapshot: snapshot,
        mode: availabilityMode,
        availabilityKey: availabilityKey,
        selectedAreaIds: serviceAreaIds,
        onModeChanged: onAvailabilityModeChanged,
        onAreaToggled: onServiceAreaToggled,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => pickDate(isStart: true),
            icon: const Icon(Icons.event_available_outlined),
            label: Text(dateLabel('Starts', publishStartsAt)),
          ),
          if (publishStartsAt != null)
            IconButton(
              tooltip: 'Clear start date',
              onPressed: () => onPublishStartsAtChanged(null),
              icon: const Icon(Icons.close),
            ),
          OutlinedButton.icon(
            onPressed: () => pickDate(isStart: false),
            icon: const Icon(Icons.event_busy_outlined),
            label: Text(dateLabel('Ends', publishEndsAt)),
          ),
          if (publishEndsAt != null)
            IconButton(
              tooltip: 'Clear end date',
              onPressed: () => onPublishEndsAtChanged(null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      if (dateError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            dateError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 12),
    ],
  );
}

class _AvailabilitySettingsEditor extends StatelessWidget {
  const _AvailabilitySettingsEditor({
    required this.snapshot,
    required this.mode,
    required this.availabilityKey,
    required this.selectedAreaIds,
    required this.onModeChanged,
    required this.onAreaToggled,
    this.inheritedHelp = 'Uses the parent category or subcategory locations.',
  });

  final _CatalogSnapshot snapshot;
  final String mode;
  final String availabilityKey;
  final Set<String> selectedAreaIds;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String> onAreaToggled;
  final String inheritedHelp;

  @override
  Widget build(BuildContext context) {
    final visibleAreas = snapshot.serviceAreas
        .where((area) => area.isActive || selectedAreaIds.contains(area.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('availability-mode:$availabilityKey:$mode'),
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Location availability'),
          items: const [
            DropdownMenuItem(value: 'INHERITED', child: Text('Inherited')),
            DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
          ],
          onChanged: (value) {
            if (value != null) onModeChanged(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          mode == 'INHERITED'
              ? inheritedHelp
              : 'Only the selected service areas will be bookable.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (mode == 'CUSTOM') ...[
          const SizedBox(height: 8),
          if (visibleAreas.isEmpty)
            Text(
              'No active service areas are configured yet.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final area in visibleAreas)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedAreaIds.contains(area.id),
                        title: Text(
                          '${area.cityName} · ${area.name}${area.pincodes.isEmpty ? '' : ' · ${area.pincodes.join(', ')}'}',
                        ),
                        subtitle: Text(
                          area.isActive
                              ? area.stateName
                              : '${area.stateName} · Inactive',
                        ),
                        onChanged: (_) => onAreaToggled(area.id),
                      ),
                  ],
                ),
              ),
            ),
          if (visibleAreas.isNotEmpty && selectedAreaIds.isEmpty)
            Text(
              'Choose at least one location. A custom item without locations cannot be booked.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ],
    );
  }
}

class CatalogManagerPage extends ConsumerStatefulWidget {
  const CatalogManagerPage({super.key, this.showFeaturedOnly = false});

  final bool showFeaturedOnly;

  @override
  ConsumerState<CatalogManagerPage> createState() => _CatalogManagerPageState();
}

class _CatalogManagerPageState extends ConsumerState<CatalogManagerPage> {
  late final _CatalogAdminApi _api;
  late Future<_CatalogSnapshot> _snapshotFuture;
  final TextEditingController _searchController = TextEditingController();
  String _catalogQuery = '';
  String _selectedCategoryId = '';
  _CatalogFilter _catalogFilter = _CatalogFilter.all;
  String _stateFilter = 'all';
  String _districtFilter = 'all';
  String _cityFilter = 'all';
  String _areaFilter = 'all';
  String _pincodeFilter = 'all';
  String _subcategoryFilter = 'all';
  String _serviceFilter = 'all';
  String _availabilityFilter = 'all';

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _loadSnapshot();
    if (widget.showFeaturedOnly) {
      _catalogFilter = _CatalogFilter.featured;
    }
  }

  Future<_CatalogSnapshot> _loadSnapshot() async {
    return _api.fetchSnapshot();
  }

  Future<void> _reload() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  ({String subcategoryId, String serviceId}) _effectiveCatalogFilters(
    _CatalogSnapshot snapshot,
  ) {
    final subcategoryIds =
        snapshot.subcategories.map((item) => item.id).toSet();
    final subcategoryId = _subcategoryFilter == 'all' ||
            subcategoryIds.contains(_subcategoryFilter)
        ? _subcategoryFilter
        : 'all';
    final availableServices = _filteredServices(
      snapshot,
      _catalogQuery,
      _catalogFilter,
    ).where((service) =>
        subcategoryId == 'all' || service.subcategoryId == subcategoryId);
    final serviceId = _serviceFilter == 'all' ||
            availableServices.any((service) => service.id == _serviceFilter)
        ? _serviceFilter
        : 'all';
    return (subcategoryId: subcategoryId, serviceId: serviceId);
  }

  List<_AdminService> _visibleCatalogServices(_CatalogSnapshot snapshot) {
    final filters = _effectiveCatalogFilters(snapshot);
    final locationFilters = _effectiveCatalogLocationFilters(
      snapshot,
      stateId: _stateFilter,
      districtId: _districtFilter,
      cityId: _cityFilter,
      areaId: _areaFilter,
      pincode: _pincodeFilter,
    );
    final base = _filteredServices(snapshot, _catalogQuery, _catalogFilter);
    final hasLocationFilter = locationFilters.stateId != 'all' ||
        locationFilters.districtId != 'all' ||
        locationFilters.cityId != 'all' ||
        locationFilters.areaId != 'all' ||
        locationFilters.pincode != 'all';
    final matchingAreas = snapshot.serviceAreas.where((area) {
      return area.isActive &&
          area.cityIsActive &&
          (locationFilters.stateId == 'all' ||
              area.stateId == locationFilters.stateId) &&
          (locationFilters.districtId == 'all' ||
              area.districtId == locationFilters.districtId) &&
          (locationFilters.cityId == 'all' ||
              area.cityId == locationFilters.cityId) &&
          (locationFilters.areaId == 'all' ||
              area.id == locationFilters.areaId) &&
          (locationFilters.pincode == 'all' ||
              area.pincodes.contains(locationFilters.pincode));
    }).toList(growable: false);
    final targetAreaIds = matchingAreas.map((area) => area.id).toSet();

    return base.where((service) {
      if (filters.subcategoryId != 'all' &&
          service.subcategoryId != filters.subcategoryId) {
        return false;
      }
      if (filters.serviceId != 'all' && service.id != filters.serviceId) {
        return false;
      }

      final subcategory = snapshot.subcategoryById(service.subcategoryId);
      final category = snapshot.categoryById(service.categoryId);
      final effectiveAreaIds = service.availabilityMode == 'CUSTOM'
          ? service.serviceAreaIds
          : subcategory?.availabilityMode == 'CUSTOM'
              ? subcategory!.serviceAreaIds
              : category?.availabilityMode == 'CUSTOM'
                  ? category!.serviceAreaIds
                  : null;
      final available = effectiveAreaIds == null
          ? targetAreaIds.isNotEmpty
          : effectiveAreaIds.any(targetAreaIds.contains);

      if (_availabilityFilter == 'INHERITED' &&
          service.availabilityMode != 'INHERITED') {
        return false;
      }
      if (_availabilityFilter == 'CUSTOM' &&
          service.availabilityMode != 'CUSTOM') {
        return false;
      }
      final shouldRequireAvailable = _availabilityFilter == 'AVAILABLE' ||
          (hasLocationFilter && _availabilityFilter != 'UNAVAILABLE');
      if (shouldRequireAvailable && !available) {
        return false;
      }
      if (_availabilityFilter == 'UNAVAILABLE' && available) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _createCategory() async {
    final payload = await _showCategoryEditor(await _snapshotFuture);
    if (payload == null) return;
    try {
      await _api.createCategory(payload);
      await _reload();
      await _showMessage('Category created');
    } catch (error) {
      await _showMessage('Unable to create category: $error');
    }
  }

  Future<void> _editCategory(_AdminCategory category) async {
    final payload =
        await _showCategoryEditor(await _snapshotFuture, existing: category);
    if (payload == null) return;
    try {
      await _api.updateCategory(category.id, payload);
      await _reload();
      await _showMessage('Category updated');
    } catch (error) {
      await _showMessage('Unable to update category: $error');
    }
  }

  Future<void> _toggleCategory(_AdminCategory category) async {
    try {
      await _api.deleteCategory(category.id);
      await _reload();
      await _showMessage('Category disabled');
    } catch (error) {
      await _showMessage('Unable to disable category: $error');
    }
  }

  Future<void> _createSubcategory(_CatalogSnapshot snapshot) async {
    final payload = await _showSubcategoryEditor(snapshot);
    if (payload == null) return;
    try {
      await _api.createSubcategory(payload);
      await _reload();
      await _showMessage('Subcategory created');
    } catch (error) {
      await _showMessage('Unable to create subcategory: $error');
    }
  }

  Future<void> _editSubcategory(
      _CatalogSnapshot snapshot, _AdminSubcategory subcategory) async {
    final payload =
        await _showSubcategoryEditor(snapshot, existing: subcategory);
    if (payload == null) return;
    try {
      await _api.updateSubcategory(subcategory.id, payload);
      await _reload();
      await _showMessage('Subcategory updated');
    } catch (error) {
      await _showMessage('Unable to update subcategory: $error');
    }
  }

  Future<void> _toggleSubcategory(_AdminSubcategory subcategory) async {
    try {
      await _api.deleteSubcategory(subcategory.id);
      await _reload();
      await _showMessage('Subcategory disabled');
    } catch (error) {
      await _showMessage('Unable to disable subcategory: $error');
    }
  }

  Future<void> _createService(_CatalogSnapshot snapshot) async {
    final payload = await _showServiceEditor(snapshot);
    if (payload == null) return;
    try {
      final created = await _api.createService(payload);
      await _reload();
      if (!mounted) return;
      final serviceId = created['id'] as String?;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Service created and saved to the catalog.'),
          action: serviceId == null
              ? null
              : SnackBarAction(
                  label: 'Manage images & pricing',
                  onPressed: () => context.push('/catalog/services/$serviceId'),
                ),
        ),
      );
    } catch (error) {
      await _showMessage('Unable to create service: $error');
    }
  }

  Future<void> _editService(
      _CatalogSnapshot snapshot, _AdminService service) async {
    final payload = await _showServiceEditor(snapshot, existing: service);
    if (payload == null) return;
    try {
      await _api.updateService(service.id, payload);
      await _reload();
      await _showMessage('Service updated');
    } catch (error) {
      await _showMessage('Unable to update service: $error');
    }
  }

  Future<void> _toggleService(_AdminService service) async {
    try {
      await _api.deleteService(service.id);
      await _reload();
      await _showMessage('Service disabled');
    } catch (error) {
      await _showMessage('Unable to disable service: $error');
    }
  }

  Future<void> _confirmBulkStatus({
    required String entityType,
    required String itemLabel,
    required Iterable<String> ids,
    required bool isActive,
  }) async {
    final itemIds = ids.toSet().toList(growable: false);
    if (itemIds.isEmpty) return;
    final action = isActive ? 'Enable' : 'Disable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action ${itemIds.length} $itemLabel?'),
        content: Text(
          isActive
              ? 'These items will become available according to their parent category and pricing setup.'
              : 'These items will no longer be offered to customers. Existing bookings and records will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _api.bulkSetActiveStatus(
        entityType: entityType,
        ids: itemIds,
        isActive: isActive,
      );
      await _reload();
      await _showMessage(
          '${result['updatedCount'] ?? itemIds.length} $itemLabel ${isActive ? 'enabled' : 'disabled'}');
    } catch (error) {
      await _showMessage('Unable to $action $itemLabel: $error');
    }
  }

  Future<void> _bulkUpdateCategories(Iterable<_AdminCategory> categories,
          {required bool isActive}) =>
      _confirmBulkStatus(
        entityType: 'categories',
        itemLabel: 'categories',
        ids: categories.map((item) => item.id),
        isActive: isActive,
      );

  Future<void> _bulkUpdateSubcategories(
          Iterable<_AdminSubcategory> subcategories,
          {required bool isActive}) =>
      _confirmBulkStatus(
        entityType: 'subcategories',
        itemLabel: 'subcategories',
        ids: subcategories.map((item) => item.id),
        isActive: isActive,
      );

  Future<void> _bulkUpdateServices(Iterable<_AdminService> services,
          {required bool isActive}) =>
      _confirmBulkStatus(
        entityType: 'services',
        itemLabel: 'services',
        ids: services.map((item) => item.id),
        isActive: isActive,
      );

  Future<void> _bulkUpdateAvailability(
      _CatalogSnapshot snapshot, List<_AdminService> visibleServices) async {
    final payload =
        await _showBulkAvailabilityDialog(snapshot, visibleServices);
    if (payload == null || !mounted) return;
    final summary = switch (payload['action']) {
      'APPLY_LOCATIONS' =>
        'Apply ${((payload['serviceIds'] as List?) ?? []).length} selected services to ${((payload['serviceAreaIds'] as List?) ?? []).length} locations?',
      'REMOVE_LOCATIONS' =>
        'Remove selected locations from ${((payload['serviceIds'] as List?) ?? []).length} services?',
      'COPY_SERVICE' =>
        'Replace the selected services\' location rules with the source service rules?',
      'APPLY_CATEGORY' =>
        'Make every subcategory, service, and variant in this category inherit the category availability?',
      _ => 'Copy the source category availability to the target category?'
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm bulk availability change'),
        content:
            Text('$summary This action may replace existing custom rules.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm change'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _api.bulkUpdateAvailability(payload);
      await _reload();
      await _showMessage(
          'Availability updated for ${result['updatedCount'] ?? 0} records');
    } catch (error) {
      await _showMessage('Unable to update availability: $error');
    }
  }

  Future<Map<String, dynamic>?> _showBulkAvailabilityDialog(
    _CatalogSnapshot snapshot,
    List<_AdminService> visibleServices,
  ) async {
    const actions = <String, String>{
      'APPLY_LOCATIONS': 'Apply locations to services',
      'COPY_SERVICE': 'Copy availability from a service',
      'APPLY_CATEGORY': 'Apply category availability to children',
      'REMOVE_LOCATIONS': 'Remove locations from services',
      'COPY_CATEGORY': 'Copy availability between categories',
    };
    var action = 'APPLY_LOCATIONS';
    var sourceServiceId = snapshot.services.firstOrNull?.id ?? '';
    final scopedCategoryId = _selectedCategoryId.isNotEmpty &&
            snapshot.categoryById(_selectedCategoryId) != null
        ? _selectedCategoryId
        : snapshot.categories.firstOrNull?.id ?? '';
    var categoryId = scopedCategoryId;
    var sourceCategoryId = scopedCategoryId;
    var targetCategoryId = snapshot.categories
            .where((item) => item.id != sourceCategoryId)
            .firstOrNull
            ?.id ??
        '';
    final targetServiceIds = visibleServices.map((item) => item.id).toSet();
    final areaIds = <String>{};

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final locationAction =
              action == 'APPLY_LOCATIONS' || action == 'REMOVE_LOCATIONS';
          final serviceCopy = action == 'COPY_SERVICE';
          final categoryAction =
              action == 'APPLY_CATEGORY' || action == 'COPY_CATEGORY';
          final sourceService = snapshot.services
              .where((item) => item.id == sourceServiceId)
              .firstOrNull;
          final targetServices = visibleServices
              .where((item) => !serviceCopy || item.id != sourceServiceId)
              .toList(growable: false);
          final body = <String, dynamic>{'action': action};
          if (locationAction || serviceCopy) {
            body['serviceIds'] = targetServices
                .where((item) => targetServiceIds.contains(item.id))
                .map((item) => item.id)
                .toList(growable: false);
          }
          if (locationAction) body['serviceAreaIds'] = areaIds.toList();
          if (serviceCopy) body['sourceServiceId'] = sourceServiceId;
          if (action == 'APPLY_CATEGORY') body['categoryId'] = categoryId;
          if (action == 'COPY_CATEGORY') {
            body['sourceCategoryId'] = sourceCategoryId;
            body['targetCategoryId'] = targetCategoryId;
          }
          final valid = switch (action) {
            'APPLY_LOCATIONS' ||
            'REMOVE_LOCATIONS' =>
              (body['serviceIds'] as List).isNotEmpty && areaIds.isNotEmpty,
            'COPY_SERVICE' =>
              sourceService != null && (body['serviceIds'] as List).isNotEmpty,
            'APPLY_CATEGORY' => categoryId.isNotEmpty,
            _ => sourceCategoryId.isNotEmpty &&
                targetCategoryId.isNotEmpty &&
                sourceCategoryId != targetCategoryId,
          };

          Widget checkboxList<T>(
              List<T> items,
              String Function(T) idOf,
              String Function(T) labelOf,
              Set<String> selected,
              ValueChanged<String> toggle) {
            if (items.isEmpty) return const Text('No matching options.');
            return SizedBox(
              height: 190,
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = idOf(item);
                  return CheckboxListTile(
                    dense: true,
                    value: selected.contains(id),
                    title: Text(labelOf(item)),
                    onChanged: (_) => toggle(id),
                  );
                },
              ),
            );
          }

          return AlertDialog(
            title: const Text('Bulk location availability'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: actions.entries
                          .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ))
                          .toList(growable: false),
                      onChanged: (value) => setDialogState(
                          () => action = value ?? 'APPLY_LOCATIONS'),
                    ),
                    if (locationAction || serviceCopy) ...[
                      const SizedBox(height: 14),
                      Text(serviceCopy ? 'Source service' : 'Target services'),
                      if (serviceCopy)
                        DropdownButtonFormField<String>(
                          initialValue:
                              sourceServiceId.isEmpty ? null : sourceServiceId,
                          items: snapshot.services
                              .map((item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) => setDialogState(
                              () => sourceServiceId = value ?? ''),
                        ),
                      checkboxList(
                        targetServices,
                        (item) => item.id,
                        (item) => item.name,
                        targetServiceIds,
                        (id) => setDialogState(() {
                          if (!targetServiceIds.add(id)) {
                            targetServiceIds.remove(id);
                          }
                        }),
                      ),
                    ],
                    if (locationAction) ...[
                      const SizedBox(height: 14),
                      const Text('Locations'),
                      checkboxList(
                        snapshot.serviceAreas
                            .where((item) => item.isActive)
                            .toList(growable: false),
                        (item) => item.id,
                        (item) =>
                            '${item.cityName} · ${item.name} (${item.pincodes.join(', ')})',
                        areaIds,
                        (id) => setDialogState(() {
                          if (!areaIds.add(id)) areaIds.remove(id);
                        }),
                      ),
                    ],
                    if (categoryAction) ...[
                      const SizedBox(height: 14),
                      if (action == 'APPLY_CATEGORY')
                        DropdownButtonFormField<String>(
                          initialValue: categoryId.isEmpty ? null : categoryId,
                          decoration:
                              const InputDecoration(labelText: 'Category'),
                          items: snapshot.categories
                              .map((item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) =>
                              setDialogState(() => categoryId = value ?? ''),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: sourceCategoryId.isEmpty
                              ? null
                              : sourceCategoryId,
                          decoration: const InputDecoration(
                              labelText: 'Copy from category'),
                          items: snapshot.categories
                              .map((item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) => setDialogState(() {
                            sourceCategoryId = value ?? '';
                            if (targetCategoryId == sourceCategoryId) {
                              targetCategoryId = snapshot.categories
                                      .where(
                                          (item) => item.id != sourceCategoryId)
                                      .firstOrNull
                                      ?.id ??
                                  '';
                            }
                          }),
                        ),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'copy-target:$sourceCategoryId:$targetCategoryId',
                          ),
                          initialValue: targetCategoryId.isEmpty ||
                                  targetCategoryId == sourceCategoryId
                              ? null
                              : targetCategoryId,
                          decoration: const InputDecoration(
                              labelText: 'Copy to category'),
                          items: snapshot.categories
                              .where((item) => item.id != sourceCategoryId)
                              .map((item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) => setDialogState(
                              () => targetCategoryId = value ?? ''),
                        ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    const Text(
                        'Bulk changes replace custom assignments in the selected scope. A separate confirmation is required before saving.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    valid ? () => Navigator.of(dialogContext).pop(body) : null,
                child: const Text('Review change'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _reorderCategories(_CatalogSnapshot snapshot) async {
    final ordered = snapshot.categories.toList(growable: true);
    final confirmed = await showDialog<List<_AdminCategory>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reorder categories'),
              content: SizedBox(
                width: 560,
                height: (ordered.length * 72).clamp(144, 480).toDouble(),
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: ordered.length,
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    final item = ordered.removeAt(oldIndex);
                    ordered.insert(newIndex, item);
                  }),
                  itemBuilder: (context, index) {
                    final category = ordered[index];
                    return ListTile(
                      key: ValueKey(category.id),
                      tileColor: AbzioTheme.lightMuted,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: CircleAvatar(
                        backgroundColor: AbzioTheme.lightBorder,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(category.name),
                      subtitle: Text(category.slug),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded),
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
                  onPressed: () => Navigator.of(dialogContext).pop(ordered),
                  child: const Text('Save order'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null) {
      return;
    }

    try {
      await _api.reorderCategories(
          confirmed.map((category) => category.id).toList(growable: false));
      await _reload();
      await _showMessage('Category order updated');
    } catch (error) {
      await _showMessage('Unable to reorder categories: $error');
    }
  }

  Future<void> _reorderSubcategories(_CatalogSnapshot snapshot) async {
    if (snapshot.categories.isEmpty) return;
    final selectedCategoryId =
        ValueNotifier<String>(snapshot.categories.first.id);
    final ordered = ValueNotifier<List<_AdminSubcategory>>(snapshot
        .subcategoriesForCategory(snapshot.categories.first.id)
        .toList(growable: true));

    final confirmed = await showDialog<_ReorderSelection<_AdminSubcategory>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final category = snapshot.categoryById(selectedCategoryId.value) ??
                snapshot.categories.first;
            final categorySubcategories =
                snapshot.subcategoriesForCategory(category.id);
            if (ordered.value.length != categorySubcategories.length) {
              ordered.value = categorySubcategories.toList(growable: true);
            }

            return AlertDialog(
              title: const Text('Reorder subcategories'),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategoryId.value,
                      items: snapshot.categories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedCategoryId.value = value;
                          ordered.value = snapshot
                              .subcategoriesForCategory(value)
                              .toList(growable: true);
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 420,
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: ordered.value.length,
                        onReorderItem: (oldIndex, newIndex) => setState(() {
                          final items = ordered.value;
                          final moved = items.removeAt(oldIndex);
                          items.insert(newIndex, moved);
                          ordered.value = [...items];
                        }),
                        itemBuilder: (context, index) {
                          final item = ordered.value[index];
                          return ListTile(
                            key: ValueKey(item.id),
                            tileColor: AbzioTheme.lightMuted,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: AbzioTheme.lightBorder,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(item.name),
                            subtitle: Text('${item.serviceCount} services'),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _ReorderSelection<_AdminSubcategory>(
                        parentId: selectedCategoryId.value,
                        items: ordered.value),
                  ),
                  child: const Text('Save order'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null) return;

    try {
      await _api.reorderSubcategories(confirmed.parentId,
          confirmed.items.map((item) => item.id).toList(growable: false));
      await _reload();
      await _showMessage('Subcategory order updated');
    } catch (error) {
      await _showMessage('Unable to reorder subcategories: $error');
    }
  }

  Future<void> _reorderServices(_CatalogSnapshot snapshot) async {
    if (snapshot.subcategories.isEmpty) return;
    final selectedSubcategoryId =
        ValueNotifier<String>(snapshot.subcategories.first.id);
    final ordered = ValueNotifier<List<_AdminService>>(snapshot
        .servicesForSubcategory(snapshot.subcategories.first.id)
        .toList(growable: true));

    final confirmed = await showDialog<_ReorderSelection<_AdminService>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategory =
                snapshot.subcategoryById(selectedSubcategoryId.value) ??
                    snapshot.subcategories.first;
            final services = snapshot.servicesForSubcategory(subcategory.id);
            if (ordered.value.length != services.length) {
              ordered.value = services.toList(growable: true);
            }

            return AlertDialog(
              title: const Text('Reorder services'),
              content: SizedBox(
                width: 680,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubcategoryId.value,
                      items: snapshot.subcategories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                  '${snapshot.categoryById(item.categoryId)?.name ?? 'Category'} / ${item.name}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedSubcategoryId.value = value;
                          ordered.value = snapshot
                              .servicesForSubcategory(value)
                              .toList(growable: true);
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Subcategory',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 420,
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: ordered.value.length,
                        onReorderItem: (oldIndex, newIndex) => setState(() {
                          final items = ordered.value;
                          final moved = items.removeAt(oldIndex);
                          items.insert(newIndex, moved);
                          ordered.value = [...items];
                        }),
                        itemBuilder: (context, index) {
                          final item = ordered.value[index];
                          return ListTile(
                            key: ValueKey(item.id),
                            tileColor: AbzioTheme.lightMuted,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: AbzioTheme.lightBorder,
                              child: Text('${index + 1}'),
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                                '₹${item.startingPrice.toStringAsFixed(0)} - ${item.estimatedDurationMins} mins'),
                            trailing: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _ReorderSelection<_AdminService>(
                        parentId: selectedSubcategoryId.value,
                        items: ordered.value),
                  ),
                  child: const Text('Save order'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == null) return;

    try {
      await _api.reorderServices(confirmed.parentId,
          confirmed.items.map((item) => item.id).toList(growable: false));
      await _reload();
      await _showMessage('Service order updated');
    } catch (error) {
      await _showMessage('Unable to reorder services: $error');
    }
  }

  Future<void> _addPricingRule(_AdminService service) async {
    final payload = await _showPricingRuleEditor(service);
    if (payload == null) return;
    try {
      await _api.addPricingRule(service.id, payload);
      await _reload();
      await _showMessage('Pricing rule saved');
    } catch (error) {
      await _showMessage('Unable to save pricing rule: $error');
    }
  }

  Future<void> _exportCatalog() async {
    try {
      final exportJson = await _api.exportCatalog();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Export catalog'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(exportJson)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      await _showMessage('Unable to export catalog: $error');
    }
  }

  Future<void> _importCatalog() async {
    final controller = TextEditingController(
        text: const JsonEncoder.withIndent('  ').convert({
      'categories': <Map<String, dynamic>>[],
    }));
    final imported = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Import catalog JSON'),
          content: SizedBox(
            width: 720,
            child: TextField(
              controller: controller,
              maxLines: 18,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                hintText: 'Paste catalog JSON here',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (imported != true) {
      return;
    }

    try {
      final decoded = jsonDecode(controller.text) as Map<String, dynamic>;
      final categories = decoded['categories'];
      if (categories is! List) {
        throw Exception('categories must be an array');
      }
      await _api.importCatalog(categories);
      await _reload();
      await _showMessage('Catalog import started');
    } catch (error) {
      await _showMessage('Unable to import catalog: $error');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addStarterCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add starter catalog?'),
        content: const Text(
          'This adds missing Veedufix starter categories, subcategories, and common services as disabled drafts. Review descriptions and prices, then enable only the items you are ready to offer. Existing entries and settings will not be changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Add missing items'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _api.addStarterCatalog();
      await _reload();
      await _showMessage(
        'Added ${result['categoryCount']} categories, ${result['subcategoryCount']} subcategories, and ${result['serviceCount']} services',
      );
    } catch (error) {
      await _showMessage('Unable to add starter catalog: $error');
    }
  }

  Future<Map<String, dynamic>?> _showCategoryEditor(_CatalogSnapshot snapshot,
      {_AdminCategory? existing}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    String? iconUrl = existing?.iconUrl;
    final sortOrderController =
        TextEditingController(text: (existing?.sortOrder ?? 0).toString());
    bool isActive = existing?.isActive ?? true;
    String availabilityMode = existing?.availabilityMode ?? 'INHERITED';
    final serviceAreaIds = <String>{...existing?.serviceAreaIds ?? const []};
    bool featured = existing?.featured ?? false;
    bool popular = existing?.popular ?? false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(existing == null ? 'Create category' : 'Edit category'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a category name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      AdminImagePickerField(
                        label: 'Category image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 800,
                        recommendedHeight: 800,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort order'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      SwitchListTile(
                        value: featured,
                        onChanged: (value) => setState(() => featured = value),
                        title: const Text('Featured'),
                      ),
                      SwitchListTile(
                        value: popular,
                        onChanged: (value) => setState(() => popular = value),
                        title: const Text('Popular'),
                      ),
                      _AvailabilitySettingsEditor(
                        snapshot: snapshot,
                        mode: availabilityMode,
                        availabilityKey: existing?.id ?? 'draft-category',
                        selectedAreaIds: serviceAreaIds,
                        onModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        inheritedHelp:
                            'Available in every active service area.',
                        onAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'iconUrl': iconUrl,
                      'sortOrder':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'isActive': isActive,
                      'featured': featured,
                      'popular': popular,
                      'availabilityMode': availabilityMode,
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      slugController.dispose();
      descriptionController.dispose();
      sortOrderController.dispose();
    });
  }

  Future<Map<String, dynamic>?> _showSubcategoryEditor(
    _CatalogSnapshot snapshot, {
    _AdminSubcategory? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final categoryIdController = ValueNotifier<String>(
      existing?.categoryId ?? snapshot.categories.firstOrNull?.id ?? '',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    String? iconUrl = existing?.iconUrl;
    final basePriceController = TextEditingController(
        text: (existing?.basePrice ?? 0).toStringAsFixed(0));
    final sortOrderController =
        TextEditingController(text: (existing?.sortOrder ?? 0).toString());
    bool isActive = existing?.isActive ?? true;
    String availabilityMode = existing?.availabilityMode ?? 'INHERITED';
    final serviceAreaIds = <String>{...existing?.serviceAreaIds ?? const []};

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                  existing == null ? 'Create subcategory' : 'Edit subcategory'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: categoryIdController.value.isEmpty
                            ? null
                            : categoryIdController.value,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(
                            () => categoryIdController.value = value ?? ''),
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a subcategory name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      AdminImagePickerField(
                        label: 'Group image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 800,
                        recommendedHeight: 800,
                      ),
                      TextFormField(
                        controller: basePriceController,
                        decoration:
                            const InputDecoration(labelText: 'Base price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort order'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      _AvailabilitySettingsEditor(
                        snapshot: snapshot,
                        mode: availabilityMode,
                        availabilityKey: existing?.id ?? 'draft-subcategory',
                        selectedAreaIds: serviceAreaIds,
                        onModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        onAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop({
                      'categoryId': categoryIdController.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'iconUrl': iconUrl,
                      'basePrice':
                          double.tryParse(basePriceController.text.trim()) ?? 0,
                      'sortOrder':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'isActive': isActive,
                      'availabilityMode': availabilityMode,
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      categoryIdController.dispose();
      nameController.dispose();
      slugController.dispose();
      descriptionController.dispose();
      basePriceController.dispose();
      sortOrderController.dispose();
    });
  }

  Future<Map<String, dynamic>?> _showServiceEditor(
    _CatalogSnapshot snapshot, {
    _AdminService? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final selectedCategoryId = ValueNotifier<String>(
      existing?.categoryId ?? snapshot.categories.firstOrNull?.id ?? '',
    );
    final selectedSubcategoryId = ValueNotifier<String>(
      existing?.subcategoryId ??
          snapshot
              .subcategoriesForCategory(existing?.categoryId ??
                  snapshot.categories.firstOrNull?.id ??
                  '')
              .firstOrNull
              ?.id ??
          '',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    final shortDescriptionController =
        TextEditingController(text: existing?.shortDescription ?? '');
    final inclusionsController =
        TextEditingController(text: existing?.inclusions.join('\n') ?? '');
    final exclusionsController =
        TextEditingController(text: existing?.exclusions.join('\n') ?? '');
    final requiredSkillsController =
        TextEditingController(text: existing?.requiredSkills.join('\n') ?? '');
    final requiredToolsController =
        TextEditingController(text: existing?.requiredTools.join('\n') ?? '');
    final requiredDocumentsController = TextEditingController(
        text: existing?.requiredDocuments.join('\n') ?? '');
    final startingPriceController = TextEditingController(
        text: (existing?.startingPrice ?? 0).toStringAsFixed(0));
    final gstRateController = TextEditingController(
        text: (existing?.gstRate ?? 18).toStringAsFixed(2));
    final sacCodeController =
        TextEditingController(text: existing?.sacCode ?? 'PENDING');
    final durationController = TextEditingController(
        text: (existing?.estimatedDurationMins ?? 0).toString());
    final warrantyController =
        TextEditingController(text: (existing?.warrantyDays ?? 0).toString());
    String? iconUrl = existing?.iconUrl;
    final seoTitleController =
        TextEditingController(text: existing?.seoTitle ?? '');
    final seoDescriptionController =
        TextEditingController(text: existing?.seoDescription ?? '');
    final seoKeywordsController =
        TextEditingController(text: existing?.seoKeywords ?? '');
    final cancellationPolicyController =
        TextEditingController(text: existing?.cancellationPolicy ?? '');
    final warrantyTextController =
        TextEditingController(text: existing?.warrantyText ?? '');
    final guaranteeWindowController = TextEditingController(
        text: (existing?.guaranteeClaimWindowDays ?? 0).toString());
    final guaranteeCategoriesController = TextEditingController(
        text: existing?.guaranteeIssueCategories.join('\n') ?? '');
    final guaranteeTermsController =
        TextEditingController(text: existing?.guaranteeTerms ?? '');
    final guaranteeExclusionsController =
        TextEditingController(text: existing?.guaranteeExclusions ?? '');
    final guaranteeRemediesController = TextEditingController(
        text: existing?.guaranteeResolutionTypes.join('\n') ?? '');
    bool guaranteeEnabled = existing?.guaranteeEnabled ?? false;
    bool guaranteeRequiresPartnerReview =
        existing?.guaranteeRequiresPartnerReview ?? false;
    bool guaranteeEvidenceRequired =
        existing?.guaranteeEvidenceRequired ?? false;
    final requirementsController =
        TextEditingController(text: existing?.requirements.join('\n') ?? '');
    final variantsController = TextEditingController(
      text: _formatServiceOptions(existing?.variants ?? const []),
    );
    final addonsController = TextEditingController(
      text: _formatServiceOptions(existing?.addons ?? const []),
    );
    final variantImageUrls = <String, String?>{
      for (final option in existing?.variants ?? const <_AdminServiceOption>[])
        option.name.trim().toLowerCase(): option.imageUrl,
    };
    final addonImageUrls = <String, String?>{
      for (final option in existing?.addons ?? const <_AdminServiceOption>[])
        option.name.trim().toLowerCase(): option.imageUrl,
    };
    final existingVariants =
        existing?.variants ?? const <_AdminServiceOption>[];
    final variantAvailabilityModes = <String, String>{
      for (final entry in existingVariants.asMap().entries)
        _variantAvailabilityKey(existingVariants, entry.key, entry.value.name):
            entry.value.availabilityMode,
    };
    final variantServiceAreaIds = <String, Set<String>>{
      for (final entry in existingVariants.asMap().entries)
        _variantAvailabilityKey(existingVariants, entry.key, entry.value.name):
            {...entry.value.serviceAreaIds},
    };
    final ctaLabelController =
        TextEditingController(text: existing?.ctaLabel ?? 'Book service');
    final ratingController = TextEditingController(
        text: existing == null ? '0' : existing.rating.toStringAsFixed(2));
    final reviewCountController = TextEditingController(
        text: existing == null ? '0' : existing.reviewCount.toString());
    final maintenanceIntervalsController = TextEditingController(
      text: existing?.maintenanceIntervalsMonths.join(', ') ?? '',
    );
    final maintenanceReminderController = TextEditingController(
      text: (existing?.maintenanceReminderHours ?? 24).toString(),
    );
    bool featured = existing?.featured ?? false;
    bool popular = existing?.popular ?? false;
    bool emergency = existing?.emergencyAvailable ?? false;
    bool homeVisit = existing?.homeVisit ?? true;
    bool requiresSiteVisit = existing?.requiresSiteVisit ?? false;
    bool isActive = existing?.isActive ?? true;
    bool bookingEnabled = existing?.bookingEnabled ?? true;
    bool maintenanceEnabled = existing?.maintenanceEnabled ?? false;
    bool gstApplicable = existing?.gstApplicable ?? true;
    String priceType = existing?.priceType ?? 'FROM';
    String publicationStatus = existing?.publicationStatus ?? 'DRAFT';
    DateTime? publishStartsAt = existing?.publishStartsAt;
    DateTime? publishEndsAt = existing?.publishEndsAt;
    String availabilityMode = existing?.availabilityMode ?? 'INHERITED';
    final serviceAreaIds = <String>{
      ...(existing?.serviceAreaIds ?? const <String>[])
    };
    String? publicationDateError;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategories =
                snapshot.subcategoriesForCategory(selectedCategoryId.value);
            if (selectedSubcategoryId.value.isEmpty &&
                subcategories.isNotEmpty) {
              selectedSubcategoryId.value = subcategories.first.id;
            }
            return AlertDialog(
              title: Text(existing == null ? 'Create service' : 'Edit service'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId.value.isEmpty
                            ? null
                            : selectedCategoryId.value,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            selectedCategoryId.value = value ?? '';
                            final nextSubcategories =
                                snapshot.subcategoriesForCategory(
                                    selectedCategoryId.value);
                            selectedSubcategoryId.value =
                                nextSubcategories.firstOrNull?.id ?? '';
                          });
                        },
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubcategoryId.value.isEmpty
                            ? null
                            : selectedSubcategoryId.value,
                        decoration:
                            const InputDecoration(labelText: 'Subcategory'),
                        items: subcategories
                            .map(
                              (subcategory) => DropdownMenuItem(
                                value: subcategory.id,
                                child: Text(subcategory.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(
                            () => selectedSubcategoryId.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Select a subcategory'
                            : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a service name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(labelText: 'Code'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: shortDescriptionController,
                        decoration: const InputDecoration(
                            labelText: 'Short description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: inclusionsController,
                        decoration: const InputDecoration(
                          labelText: 'What’s included',
                          helperText: 'One item per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: exclusionsController,
                        decoration: const InputDecoration(
                          labelText: 'What’s not included',
                          helperText: 'One item per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: requiredSkillsController,
                        decoration: const InputDecoration(
                          labelText: 'Required skills',
                          helperText: 'One skill per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: requiredToolsController,
                        decoration: const InputDecoration(
                          labelText: 'Required tools',
                          helperText: 'One tool per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: requiredDocumentsController,
                        decoration: const InputDecoration(
                          labelText: 'Required documents',
                          helperText: 'One document per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: startingPriceController,
                        decoration:
                            const InputDecoration(labelText: 'Starting price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: gstRateController,
                        decoration:
                            const InputDecoration(labelText: 'GST rate (%)'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: gstApplicable,
                        onChanged: (value) =>
                            setState(() => gstApplicable = value),
                        title: const Text('GST applicable'),
                      ),
                      TextFormField(
                        controller: sacCodeController,
                        decoration:
                            const InputDecoration(labelText: 'SAC code'),
                      ),
                      TextFormField(
                        controller: durationController,
                        decoration: const InputDecoration(
                            labelText: 'Estimated duration (mins)'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyController,
                        decoration:
                            const InputDecoration(labelText: 'Warranty days'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyTextController,
                        decoration: const InputDecoration(
                            labelText: 'Warranty terms (optional)'),
                        maxLines: 3,
                      ),
                      const Divider(height: 28),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: guaranteeEnabled,
                        onChanged: (value) =>
                            setState(() => guaranteeEnabled = value),
                        title: const Text('Enable service guarantee claims'),
                        subtitle: const Text(
                            'Only enable after business policy approval. No refund or free rework is promised automatically.'),
                      ),
                      if (guaranteeEnabled) ...[
                        TextFormField(
                            controller: guaranteeWindowController,
                            decoration: const InputDecoration(
                                labelText:
                                    'Claim window after completion (days)'),
                            keyboardType: TextInputType.number),
                        TextFormField(
                            controller: guaranteeCategoriesController,
                            decoration: const InputDecoration(
                                labelText: 'Eligible issue categories',
                                helperText:
                                    'One per line; e.g. incomplete work, poor workmanship, damage'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeTermsController,
                            decoration: const InputDecoration(
                                labelText: 'Guarantee terms'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeExclusionsController,
                            decoration: const InputDecoration(
                                labelText: 'Guarantee exclusions'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeRemediesController,
                            validator: _validateGuaranteeRemedies,
                            decoration: const InputDecoration(
                                labelText: 'Permitted resolution types',
                                helperText:
                                    'Use REWORK, REVISIT, or REFUND_REVIEW (one per line)'),
                            maxLines: 3),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: guaranteeRequiresPartnerReview,
                            onChanged: (value) => setState(
                                () => guaranteeRequiresPartnerReview = value),
                            title: const Text(
                                'Request Partner response during review')),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: guaranteeEvidenceRequired,
                            onChanged: (value) => setState(
                                () => guaranteeEvidenceRequired = value),
                            title: const Text('Require supporting photos')),
                      ],
                      TextFormField(
                        controller: requirementsController,
                        decoration: const InputDecoration(
                          labelText: 'Before booking requirements',
                          helperText: 'One requirement per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: variantsController,
                        decoration: const InputDecoration(
                          labelText: 'Service options / variants',
                          helperText:
                              'One per line: name | price | duration minutes | active/inactive | description',
                        ),
                        maxLines: 4,
                        validator: _validateServiceOptionLines,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildServiceOptionImageEditors(
                        context: context,
                        controller: variantsController,
                        selectedImageUrls: variantImageUrls,
                        label: 'Variant images',
                        setState: setState,
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                      ),
                      _buildServiceOptionAvailabilityEditors(
                        context: context,
                        snapshot: snapshot,
                        controller: variantsController,
                        existingVariants: existingVariants,
                        modes: variantAvailabilityModes,
                        areaIds: variantServiceAreaIds,
                        setState: setState,
                      ),
                      TextFormField(
                        controller: addonsController,
                        decoration: const InputDecoration(
                          labelText: 'Optional add-ons',
                          helperText:
                              'One per line: name | price | duration minutes | active/inactive | description',
                        ),
                        maxLines: 4,
                        validator: _validateServiceOptionLines,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildServiceOptionImageEditors(
                        context: context,
                        controller: addonsController,
                        selectedImageUrls: addonImageUrls,
                        label: 'Add-on images',
                        setState: setState,
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                      ),
                      _buildPublicationControls(
                        context: context,
                        snapshot: snapshot,
                        publicationStatus: publicationStatus,
                        availabilityMode: availabilityMode,
                        availabilityKey: existing?.id ?? 'draft-service',
                        publishStartsAt: publishStartsAt,
                        publishEndsAt: publishEndsAt,
                        serviceAreaIds: serviceAreaIds,
                        dateError: publicationDateError,
                        onPublicationStatusChanged: (value) =>
                            setState(() => publicationStatus = value),
                        onAvailabilityModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        onPublishStartsAtChanged: (value) => setState(() {
                          publishStartsAt = value;
                          publicationDateError = null;
                        }),
                        onPublishEndsAtChanged: (value) => setState(() {
                          publishEndsAt = value;
                          publicationDateError = null;
                        }),
                        onServiceAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: priceType,
                        decoration: const InputDecoration(
                            labelText: 'Customer price label'),
                        items: const [
                          DropdownMenuItem(
                              value: 'FIXED', child: Text('Fixed price')),
                          DropdownMenuItem(
                              value: 'FROM', child: Text('Starting from')),
                          DropdownMenuItem(
                              value: 'QUOTE',
                              child: Text('Price after assessment')),
                        ],
                        onChanged: (value) =>
                            setState(() => priceType = value ?? 'FROM'),
                      ),
                      TextFormField(
                        controller: ctaLabelController,
                        decoration: const InputDecoration(
                            labelText: 'Booking button text'),
                        maxLength: 40,
                      ),
                      AdminImagePickerField(
                        label: 'Service image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 1200,
                        recommendedHeight: 840,
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration:
                            const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration:
                            const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: seoKeywordsController,
                        decoration: const InputDecoration(
                          labelText: 'Search aliases / SEO keywords',
                          helperText:
                              'Comma-separated service names and phrases customers may search for.',
                        ),
                      ),
                      TextFormField(
                        controller: cancellationPolicyController,
                        decoration: const InputDecoration(
                            labelText: 'Cancellation policy'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration:
                            const InputDecoration(labelText: 'Review count'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: featured,
                        onChanged: (value) => setState(() => featured = value),
                        title: const Text('Featured'),
                      ),
                      SwitchListTile(
                        value: popular,
                        onChanged: (value) => setState(() => popular = value),
                        title: const Text('Popular'),
                      ),
                      SwitchListTile(
                        value: emergency,
                        onChanged: (value) => setState(() => emergency = value),
                        title: const Text('Emergency available'),
                      ),
                      SwitchListTile(
                        value: homeVisit,
                        onChanged: (value) => setState(() => homeVisit = value),
                        title: const Text('Home visit'),
                      ),
                      SwitchListTile(
                        value: requiresSiteVisit,
                        onChanged: (value) =>
                            setState(() => requiresSiteVisit = value),
                        title: const Text('Requires site visit (Big Job)'),
                        subtitle: const Text(
                            'Worker visits first to generate a custom quote'),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      SwitchListTile(
                        value: bookingEnabled,
                        onChanged: (value) =>
                            setState(() => bookingEnabled = value),
                        title: const Text('Booking enabled'),
                        subtitle: const Text(
                            'Disable temporarily without hiding the service.'),
                      ),
                      SwitchListTile(
                        value: maintenanceEnabled,
                        onChanged: (value) =>
                            setState(() => maintenanceEnabled = value),
                        title: const Text('Recurring maintenance plans'),
                        subtitle: const Text(
                            'Eligible customers can create a plan. Each visit still requires customer confirmation and checkout.'),
                      ),
                      if (maintenanceEnabled) ...[
                        TextFormField(
                          controller: maintenanceIntervalsController,
                          decoration: const InputDecoration(
                              labelText: 'Allowed intervals (months)',
                              hintText: '1, 3, 6, 12'),
                          validator: (value) {
                            if (!maintenanceEnabled) return null;
                            final tokens = (value ?? '')
                                .split(',')
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList();
                            final values = tokens
                                .map((item) => int.tryParse(item))
                                .whereType<int>()
                                .toList();
                            if (tokens.isEmpty ||
                                values.length != tokens.length ||
                                values.any((item) => item < 1 || item > 24) ||
                                values.toSet().length != values.length) {
                              return 'Enter unique month intervals from 1 to 24.';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: maintenanceReminderController,
                          decoration: const InputDecoration(
                              labelText: 'Reminder lead time (hours)'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!maintenanceEnabled) return null;
                            final hours = int.tryParse(value ?? '');
                            return hours == null || hours < 1 || hours > 720
                                ? 'Enter 1 to 720 hours.'
                                : null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (_hasUncoveredCustomVariant(
                      variantsController.text,
                      existingVariants,
                      variantAvailabilityModes,
                      variantServiceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(
                        dialogContext,
                        isVariant: true,
                      );
                      return;
                    }
                    if (publishStartsAt != null &&
                        publishEndsAt != null &&
                        !publishEndsAt!.isAfter(publishStartsAt!)) {
                      setState(() => publicationDateError =
                          'End date must be after the start date.');
                      return;
                    }
                    Navigator.of(dialogContext).pop({
                      'categoryId': selectedCategoryId.value,
                      'subcategoryId': selectedSubcategoryId.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'code': codeController.text.trim().isEmpty
                          ? null
                          : codeController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'shortDescription':
                          shortDescriptionController.text.trim().isEmpty
                              ? null
                              : shortDescriptionController.text.trim(),
                      'startingPrice': double.tryParse(
                              startingPriceController.text.trim()) ??
                          0,
                      'gstRate':
                          double.tryParse(gstRateController.text.trim()) ?? 18,
                      'sacCode': sacCodeController.text.trim().isEmpty
                          ? 'PENDING'
                          : sacCodeController.text.trim(),
                      'estimatedDurationMins':
                          int.tryParse(durationController.text.trim()) ?? 0,
                      'warrantyDays':
                          int.tryParse(warrantyController.text.trim()) ?? 0,
                      'inclusions': _serviceLines(inclusionsController.text),
                      'exclusions': _serviceLines(exclusionsController.text),
                      'requiredSkills': _serviceRequirementRows(
                          requiredSkillsController.text),
                      'requiredTools':
                          _serviceRequirementRows(requiredToolsController.text),
                      'requiredDocuments': _serviceRequirementRows(
                          requiredDocumentsController.text),
                      'warrantyText': warrantyTextController.text.trim().isEmpty
                          ? null
                          : warrantyTextController.text.trim(),
                      'guaranteeEnabled': guaranteeEnabled,
                      'guaranteeClaimWindowDays': guaranteeEnabled
                          ? (int.tryParse(
                                  guaranteeWindowController.text.trim()) ??
                              0)
                          : 0,
                      'guaranteeIssueCategories':
                          _serviceLines(guaranteeCategoriesController.text),
                      'guaranteeTerms':
                          guaranteeTermsController.text.trim().isEmpty
                              ? null
                              : guaranteeTermsController.text.trim(),
                      'guaranteeExclusions':
                          guaranteeExclusionsController.text.trim().isEmpty
                              ? null
                              : guaranteeExclusionsController.text.trim(),
                      'guaranteeResolutionTypes':
                          _serviceLines(guaranteeRemediesController.text)
                              .map((value) => value.toUpperCase())
                              .toList(growable: false),
                      'guaranteeRequiresPartnerReview':
                          guaranteeRequiresPartnerReview,
                      'guaranteeEvidenceRequired': guaranteeEvidenceRequired,
                      'requirements': requirementsController.text
                          .split('\n')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(growable: false),
                      'variants': _serviceOptionRows(
                        variantsController.text,
                        existing?.variants ?? const [],
                        isVariant: true,
                        imageUrls: variantImageUrls,
                        availabilityModes: variantAvailabilityModes,
                        serviceAreaIds: variantServiceAreaIds,
                      ),
                      'addons': _serviceOptionRows(
                        addonsController.text,
                        existing?.addons ?? const [],
                        isVariant: false,
                        imageUrls: addonImageUrls,
                      ),
                      'priceType': priceType,
                      'ctaLabel': ctaLabelController.text.trim().isEmpty
                          ? 'Book service'
                          : ctaLabelController.text.trim(),
                      'iconUrl': iconUrl,
                      'seoTitle': seoTitleController.text.trim().isEmpty
                          ? null
                          : seoTitleController.text.trim(),
                      'seoDescription':
                          seoDescriptionController.text.trim().isEmpty
                              ? null
                              : seoDescriptionController.text.trim(),
                      'seoKeywords': seoKeywordsController.text.trim().isEmpty
                          ? null
                          : seoKeywordsController.text.trim(),
                      'cancellationPolicy':
                          cancellationPolicyController.text.trim().isEmpty
                              ? null
                              : cancellationPolicyController.text.trim(),
                      'rating':
                          double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount':
                          int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'emergencyAvailable': emergency,
                      'gstApplicable': gstApplicable,
                      'homeVisit': homeVisit,
                      'requiresSiteVisit': requiresSiteVisit,
                      'isActive': isActive,
                      'bookingEnabled': bookingEnabled,
                      'publicationStatus': publicationStatus,
                      'publishStartsAt':
                          publishStartsAt?.toUtc().toIso8601String(),
                      'publishEndsAt': publishEndsAt?.toUtc().toIso8601String(),
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                      'availabilityMode': availabilityMode,
                      'maintenanceEnabled': maintenanceEnabled,
                      'maintenanceIntervalsMonths': maintenanceEnabled
                          ? maintenanceIntervalsController.text
                              .split(',')
                              .map((item) => int.tryParse(item.trim()))
                              .whereType<int>()
                              .toList()
                          : <int>[],
                      'maintenanceReminderHours': int.tryParse(
                              maintenanceReminderController.text.trim()) ??
                          24,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      selectedCategoryId.dispose();
      selectedSubcategoryId.dispose();
      nameController.dispose();
      slugController.dispose();
      codeController.dispose();
      descriptionController.dispose();
      shortDescriptionController.dispose();
      inclusionsController.dispose();
      exclusionsController.dispose();
      requiredSkillsController.dispose();
      requiredToolsController.dispose();
      requiredDocumentsController.dispose();
      startingPriceController.dispose();
      gstRateController.dispose();
      sacCodeController.dispose();
      durationController.dispose();
      warrantyController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      seoKeywordsController.dispose();
      cancellationPolicyController.dispose();
      warrantyTextController.dispose();
      guaranteeWindowController.dispose();
      guaranteeCategoriesController.dispose();
      guaranteeTermsController.dispose();
      guaranteeExclusionsController.dispose();
      guaranteeRemediesController.dispose();
      requirementsController.dispose();
      variantsController.dispose();
      addonsController.dispose();
      ctaLabelController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
      maintenanceIntervalsController.dispose();
      maintenanceReminderController.dispose();
    });
  }

  Future<Map<String, dynamic>?> _showPricingRuleEditor(_AdminService service) {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: 'BASE');
    final titleController =
        TextEditingController(text: '${service.name} base price');
    final cityIdController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController =
        TextEditingController(text: service.startingPrice.toStringAsFixed(0));
    final priorityController = TextEditingController(text: '0');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Pricing rule for ${service.name}'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: typeController.text,
                    decoration: const InputDecoration(labelText: 'Rule type'),
                    items: const [
                      DropdownMenuItem(value: 'BASE', child: Text('BASE')),
                      DropdownMenuItem(value: 'CITY', child: Text('CITY')),
                      DropdownMenuItem(
                          value: 'SEASONAL', child: Text('SEASONAL')),
                      DropdownMenuItem(
                          value: 'PROMOTIONAL', child: Text('PROMOTIONAL')),
                      DropdownMenuItem(value: 'SURGE', child: Text('SURGE')),
                      DropdownMenuItem(value: 'WORKER', child: Text('WORKER')),
                    ],
                    onChanged: (value) => typeController.text = value ?? 'BASE',
                  ),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => (value ?? '').trim().length < 2
                        ? 'Enter a title'
                        : null,
                  ),
                  TextFormField(
                    controller: cityIdController,
                    decoration:
                        const InputDecoration(labelText: 'City ID (optional)'),
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  TextFormField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: priorityController,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final payload = <String, dynamic>{
                  'type': typeController.text,
                  'title': titleController.text.trim(),
                  'currency': 'INR',
                  'price': double.tryParse(priceController.text.trim()) ??
                      service.startingPrice,
                  'priority': int.tryParse(priorityController.text.trim()) ?? 0,
                };
                final cityId = cityIdController.text.trim();
                final description = descriptionController.text.trim();
                if (cityId.isNotEmpty) payload['cityId'] = cityId;
                if (description.isNotEmpty) {
                  payload['description'] = description;
                }
                Navigator.of(dialogContext).pop(payload);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      typeController.dispose();
      titleController.dispose();
      cityIdController.dispose();
      descriptionController.dispose();
      priceController.dispose();
      priorityController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<_CatalogSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting;
              final data = snapshot.data;
              final selectedCategory = data?.categoryById(_selectedCategoryId);
              final scopedSnapshot = data == null ||
                      _selectedCategoryId.isEmpty ||
                      selectedCategory == null
                  ? data
                  : _CatalogSnapshot(
                      categories: [selectedCategory],
                      serviceAreas: data.serviceAreas,
                    );
              final visibleCategories = scopedSnapshot == null
                  ? const <_AdminCategory>[]
                  : _filteredCategories(
                      scopedSnapshot, _catalogQuery, _catalogFilter);
              final visibleSubcategories = scopedSnapshot == null
                  ? const <_AdminSubcategory>[]
                  : _filteredSubcategories(
                      scopedSnapshot, _catalogQuery, _catalogFilter);
              final visibleServices = scopedSnapshot == null
                  ? const <_AdminService>[]
                  : _visibleCatalogServices(scopedSnapshot);
              final catalogFilters = scopedSnapshot == null
                  ? null
                  : _effectiveCatalogFilters(scopedSnapshot);

              return NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Catalog Manager',
                                      style: GoogleFonts.outfit(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Manage categories, services, pricing, images, and bulk imports without code changes.',
                                      style: GoogleFonts.outfit(
                                        color: Colors.black54,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: loading ? null : _reload,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: loading
                                    ? null
                                    : () => _createService(
                                        data ?? const _CatalogSnapshot.empty()),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('New service'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SearchBar(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _catalogQuery = value.trim()),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'category-scope:${selectedCategory?.id ?? ''}',
                            ),
                            initialValue: selectedCategory == null
                                ? ''
                                : selectedCategory.id,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category scope',
                              prefixIcon: Icon(Icons.account_tree_outlined),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('All categories')),
                              ...?data?.categories.map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: data == null
                                ? null
                                : (value) => setState(() {
                                      _selectedCategoryId = value ?? '';
                                      _subcategoryFilter = 'all';
                                      _serviceFilter = 'all';
                                    }),
                          ),
                          const SizedBox(height: 12),
                          if (scopedSnapshot != null && catalogFilters != null)
                            _CatalogLocationFilterBar(
                              snapshot: scopedSnapshot,
                              categoryId: selectedCategory?.id ?? 'all',
                              stateId: _stateFilter,
                              districtId: _districtFilter,
                              cityId: _cityFilter,
                              areaId: _areaFilter,
                              pincode: _pincodeFilter,
                              subcategoryId: catalogFilters.subcategoryId,
                              serviceId: catalogFilters.serviceId,
                              availability: _availabilityFilter,
                              onChanged: (key, value) => setState(() {
                                switch (key) {
                                  case 'state':
                                    _stateFilter = value;
                                    _districtFilter = 'all';
                                    _cityFilter = 'all';
                                    _areaFilter = 'all';
                                    _pincodeFilter = 'all';
                                  case 'district':
                                    _districtFilter = value;
                                    _cityFilter = 'all';
                                    _areaFilter = 'all';
                                    _pincodeFilter = 'all';
                                  case 'city':
                                    _cityFilter = value;
                                    _areaFilter = 'all';
                                    _pincodeFilter = 'all';
                                  case 'area':
                                    _areaFilter = value;
                                    _pincodeFilter = 'all';
                                  case 'pincode':
                                    _pincodeFilter = value;
                                  case 'subcategory':
                                    _subcategoryFilter = value;
                                    _serviceFilter = 'all';
                                  case 'service':
                                    _serviceFilter = value;
                                  case 'availability':
                                    _availabilityFilter = value;
                                }
                              }),
                              onClear: () => setState(() {
                                _stateFilter = 'all';
                                _districtFilter = 'all';
                                _cityFilter = 'all';
                                _areaFilter = 'all';
                                _pincodeFilter = 'all';
                                _subcategoryFilter = 'all';
                                _serviceFilter = 'all';
                                _availabilityFilter = 'all';
                              }),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _CatalogFilter.values
                                .map(
                                  (filter) => ChoiceChip(
                                    label: Text(filter.label),
                                    selected: _catalogFilter == filter,
                                    onSelected: (_) =>
                                        setState(() => _catalogFilter = filter),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          if (!loading && data != null)
                            _OverviewMetrics(snapshot: data),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _CatalogTabBarDelegate(),
                  ),
                ],
                body: loading && data == null
                    ? const Center(child: CircularProgressIndicator())
                    : data == null
                        ? _ErrorState(onRetry: _reload)
                        : TabBarView(
                            children: [
                              _CategoriesTab(
                                snapshot: scopedSnapshot ?? data,
                                query: _catalogQuery,
                                filter: _catalogFilter,
                                visibleCount: visibleCategories.length,
                                onCreate: _createCategory,
                                onEdit: _editCategory,
                                onDisable: _toggleCategory,
                                onReorder: () => _reorderCategories(data),
                                onBulkEnable: () => _bulkUpdateCategories(
                                    visibleCategories,
                                    isActive: true),
                                onBulkDisable: () => _bulkUpdateCategories(
                                    visibleCategories,
                                    isActive: false),
                              ),
                              _SubcategoriesTab(
                                snapshot: scopedSnapshot ?? data,
                                query: _catalogQuery,
                                filter: _catalogFilter,
                                visibleCount: visibleSubcategories.length,
                                onCreate: () => _createSubcategory(data),
                                onEdit: (subcategory) =>
                                    _editSubcategory(data, subcategory),
                                onDisable: _toggleSubcategory,
                                onReorder: () => _reorderSubcategories(data),
                                onBulkEnable: () => _bulkUpdateSubcategories(
                                    visibleSubcategories,
                                    isActive: true),
                                onBulkDisable: () => _bulkUpdateSubcategories(
                                    visibleSubcategories,
                                    isActive: false),
                              ),
                              _ServicesTab(
                                snapshot: scopedSnapshot ?? data,
                                services: visibleServices,
                                query: _catalogQuery,
                                filter: _catalogFilter,
                                visibleCount: visibleServices.length,
                                onCreate: () => _createService(data),
                                onEdit: (service) =>
                                    _editService(data, service),
                                onDisable: _toggleService,
                                onPricingRule: _addPricingRule,
                                onReorder: () => _reorderServices(data),
                                onBulkEnable: () => _bulkUpdateServices(
                                    visibleServices,
                                    isActive: true),
                                onBulkDisable: () => _bulkUpdateServices(
                                    visibleServices,
                                    isActive: false),
                                onBulkAvailability: () =>
                                    _bulkUpdateAvailability(
                                        data, visibleServices),
                              ),
                              _PricingTab(
                                snapshot: scopedSnapshot ?? data,
                                services: visibleServices,
                                query: _catalogQuery,
                                filter: _catalogFilter,
                                onPricingRule: _addPricingRule,
                              ),
                              _ImportExportTab(
                                onImport: _importCatalog,
                                onExport: _exportCatalog,
                                onAddStarter: _addStarterCatalog,
                              ),
                            ],
                          ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogTabBarDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const TabBar(
        isScrollable: true,
        tabs: [
          Tab(text: 'Categories'),
          Tab(text: 'Subcategories'),
          Tab(text: 'Services'),
          Tab(text: 'Pricing'),
          Tab(text: 'Import/Export'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CatalogTabBarDelegate oldDelegate) => false;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search_rounded),
        hintText: 'Search category, subcategory, service, or slug',
      ),
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.snapshot});

  final _CatalogSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final totalCategories = snapshot.categories.length;
    final totalSubcategories = snapshot.subcategories.length;
    final totalServices = snapshot.services.length;
    final activeServices =
        snapshot.services.where((service) => service.isActive).length;
    final metrics = <_MetricData>[
      _MetricData(
          label: 'Categories',
          value: totalCategories.toString(),
          icon: Icons.category_rounded,
          accent: AbzioTheme.accentColor),
      _MetricData(
          label: 'Subcategories',
          value: totalSubcategories.toString(),
          icon: Icons.view_module_rounded,
          accent: AbzioTheme.accentColor),
      _MetricData(
          label: 'Services',
          value: totalServices.toString(),
          icon: Icons.design_services_rounded,
          accent: AbzioTheme.successColor),
      _MetricData(
          label: 'Active',
          value: activeServices.toString(),
          icon: Icons.verified_rounded,
          accent: AbzioTheme.accentColor),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 440
                ? 2
                : 1;
        final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: PremiumStatCard(
                    label: metric.label,
                    value: metric.value,
                    icon: metric.icon,
                    accentColor: metric.accent,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
}

bool _matchesQuery(Iterable<String> fields, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }

  return fields.any((field) => field.toLowerCase().contains(needle));
}

bool _matchesCatalogFilter({
  required bool isActive,
  required bool featured,
  required bool popular,
  required _CatalogFilter filter,
}) {
  return switch (filter) {
    _CatalogFilter.all => true,
    _CatalogFilter.active => isActive,
    _CatalogFilter.inactive => !isActive,
    _CatalogFilter.featured => featured,
    _CatalogFilter.popular => popular,
  };
}

List<_AdminCategory> _filteredCategories(
    _CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
  return snapshot.categories.where((category) {
    return _matchesCatalogFilter(
          isActive: category.isActive,
          featured: category.featured,
          popular: category.popular,
          filter: filter,
        ) &&
        _matchesQuery([
          category.name,
          category.slug,
          category.description ?? '',
          ...category.subcategories.expand((subcategory) => [
                subcategory.name,
                subcategory.slug,
                subcategory.description ?? '',
                ...subcategory.services.map((service) => service.name),
              ]),
        ], query);
  }).toList(growable: false);
}

List<_AdminSubcategory> _filteredSubcategories(
    _CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
  return snapshot.subcategories.where((subcategory) {
    return _matchesCatalogFilter(
          isActive: subcategory.isActive,
          featured: false,
          popular: false,
          filter: filter,
        ) &&
        _matchesQuery([
          subcategory.name,
          subcategory.slug,
          subcategory.description ?? '',
          snapshot.categoryById(subcategory.categoryId)?.name ?? '',
        ], query);
  }).toList(growable: false);
}

List<_AdminService> _filteredServices(
    _CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
  return snapshot.services.where((service) {
    final category = snapshot.categoryById(service.categoryId);
    final subcategory = snapshot.subcategoryById(service.subcategoryId);
    return _matchesCatalogFilter(
          isActive: service.isActive,
          featured: service.featured,
          popular: service.popular,
          filter: filter,
        ) &&
        _matchesQuery([
          service.name,
          service.slug,
          service.code ?? '',
          service.description ?? '',
          service.shortDescription ?? '',
          category?.name ?? '',
          subcategory?.name ?? '',
        ], query);
  }).toList(growable: false);
}

enum _CatalogFilter {
  all('All'),
  active('Active'),
  inactive('Inactive'),
  featured('Featured'),
  popular('Popular');

  const _CatalogFilter(this.label);

  final String label;
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({
    required this.snapshot,
    required this.query,
    required this.filter,
    required this.visibleCount,
    required this.onCreate,
    required this.onEdit,
    required this.onDisable,
    required this.onReorder,
    required this.onBulkEnable,
    required this.onBulkDisable,
  });

  final _CatalogSnapshot snapshot;
  final String query;
  final _CatalogFilter filter;
  final int visibleCount;
  final VoidCallback onCreate;
  final ValueChanged<_AdminCategory> onEdit;
  final ValueChanged<_AdminCategory> onDisable;
  final VoidCallback onReorder;
  final VoidCallback onBulkEnable;
  final VoidCallback onBulkDisable;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create, edit, disable, and reorder main service categories.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonal(
              onPressed: onCreate,
              child: const Text('Create category'),
            ),
            FilledButton.tonal(
              onPressed: onReorder,
              child: const Text('Reorder'),
            ),
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkEnable,
              child: Text('Enable filtered ($visibleCount)'),
            ),
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkDisable,
              child: Text('Disable filtered ($visibleCount)'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...snapshot.categories.where((category) {
          return _matchesCatalogFilter(
                isActive: category.isActive,
                featured: category.featured,
                popular: category.popular,
                filter: filter,
              ) &&
              _matchesQuery([
                category.name,
                category.slug,
                category.description ?? '',
                ...category.subcategories.expand((subcategory) => [
                      subcategory.name,
                      subcategory.slug,
                      subcategory.description ?? '',
                      ...subcategory.services.map((service) => service.name),
                    ]),
              ], query);
        }).map(
          (category) => _CatalogCard(
            title: category.name,
            subtitle:
                'Order ${category.sortOrder} · ${category.subcategories.length} subcategories · ${category.serviceCount} services · ${category.availabilityMode == 'INHERITED' ? 'Inherited' : 'Custom'} availability',
            tag: category.isActive ? 'Active' : 'Disabled',
            imageUrl: category.iconUrl,
            accent: category.featured
                ? AbzioTheme.accentColor
                : AbzioTheme.successColor,
            onTap: () => context.push('/catalog/categories/${category.id}'),
            onEdit: () => onEdit(category),
            onDisable: () => onDisable(category),
          ),
        ),
      ],
    );
  }
}

class _SubcategoriesTab extends StatelessWidget {
  const _SubcategoriesTab({
    required this.snapshot,
    required this.query,
    required this.filter,
    required this.visibleCount,
    required this.onCreate,
    required this.onEdit,
    required this.onDisable,
    required this.onReorder,
    required this.onBulkEnable,
    required this.onBulkDisable,
  });

  final _CatalogSnapshot snapshot;
  final String query;
  final _CatalogFilter filter;
  final int visibleCount;
  final VoidCallback onCreate;
  final ValueChanged<_AdminSubcategory> onEdit;
  final ValueChanged<_AdminSubcategory> onDisable;
  final VoidCallback onReorder;
  final VoidCallback onBulkEnable;
  final VoidCallback onBulkDisable;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subcategory management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Assign pricing, icons, translations, and active status.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onCreate,
          child: const Text('Create subcategory'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReorder,
          icon: const Icon(Icons.swap_vert_rounded),
          label: const Text('Reorder subcategories'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkEnable,
              child: Text('Enable filtered ($visibleCount)'),
            ),
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkDisable,
              child: Text('Disable filtered ($visibleCount)'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...snapshot.subcategories.where((subcategory) {
          return _matchesCatalogFilter(
                isActive: subcategory.isActive,
                featured: false,
                popular: false,
                filter: filter,
              ) &&
              _matchesQuery([
                subcategory.name,
                subcategory.slug,
                subcategory.description ?? '',
                snapshot.categoryById(subcategory.categoryId)?.name ?? '',
              ], query);
        }).map(
          (subcategory) {
            final category = snapshot.categoryById(subcategory.categoryId);
            return _CatalogCard(
              title: subcategory.name,
              subtitle:
                  '${category?.name ?? 'Category'} · Order ${subcategory.sortOrder} · ${subcategory.serviceCount} services · ₹${subcategory.basePrice.toStringAsFixed(0)} base · ${subcategory.availabilityMode == 'INHERITED' ? 'Inherited' : 'Custom'} availability',
              tag: subcategory.isActive ? 'Active' : 'Disabled',
              imageUrl: subcategory.iconUrl,
              accent: AbzioTheme.accentColor,
              onTap: () =>
                  context.push('/catalog/subcategories/${subcategory.id}'),
              onEdit: () => onEdit(subcategory),
              onDisable: () => onDisable(subcategory),
            );
          },
        ),
      ],
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({
    required this.snapshot,
    required this.services,
    required this.query,
    required this.filter,
    required this.visibleCount,
    required this.onCreate,
    required this.onEdit,
    required this.onDisable,
    required this.onPricingRule,
    required this.onReorder,
    required this.onBulkEnable,
    required this.onBulkDisable,
    required this.onBulkAvailability,
  });

  final _CatalogSnapshot snapshot;
  final List<_AdminService> services;
  final String query;
  final _CatalogFilter filter;
  final int visibleCount;
  final VoidCallback onCreate;
  final ValueChanged<_AdminService> onEdit;
  final ValueChanged<_AdminService> onDisable;
  final ValueChanged<_AdminService> onPricingRule;
  final VoidCallback onReorder;
  final VoidCallback onBulkEnable;
  final VoidCallback onBulkDisable;
  final VoidCallback onBulkAvailability;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Edit descriptions, images, durations, skills, and SEO metadata.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: onCreate,
          child: const Text('Create service'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onReorder,
          icon: const Icon(Icons.swap_vert_rounded),
          label: const Text('Reorder services'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkEnable,
              child: Text('Enable filtered ($visibleCount)'),
            ),
            OutlinedButton(
              onPressed: visibleCount == 0 ? null : onBulkDisable,
              child: Text('Disable filtered ($visibleCount)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: visibleCount == 0 ? null : onBulkAvailability,
          icon: const Icon(Icons.location_on_outlined),
          label: const Text('Bulk location availability'),
        ),
        const SizedBox(height: 16),
        ...services.map(
          (service) {
            final category = snapshot.categoryById(service.categoryId);
            final subcategory = snapshot.subcategoryById(service.subcategoryId);
            return _CatalogCard(
              title: service.name,
              subtitle:
                  '${category?.name ?? 'Category'} / ${subcategory?.name ?? 'Subcategory'} - ₹${service.startingPrice.toStringAsFixed(0)} - GST ${service.gstRate.toStringAsFixed(2)}% - SAC ${service.sacCode} - ${service.estimatedDurationMins} mins - ${service.availabilityMode == 'INHERITED' ? 'Inherited' : 'Custom'} availability',
              tag: service.isActive ? 'Active' : 'Disabled',
              imageUrl: service.iconUrl,
              accent: service.featured
                  ? AbzioTheme.accentColor
                  : AbzioTheme.successColor,
              onTap: () => context.push('/catalog/services/${service.id}'),
              onEdit: () => onEdit(service),
              onDisable: () => onDisable(service),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => onPricingRule(service),
                    icon: const Icon(Icons.payments_rounded),
                    tooltip: 'Add pricing rule',
                  ),
                  IconButton(
                    onPressed: () => onEdit(service),
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit service',
                  ),
                  IconButton(
                    onPressed: () => onDisable(service),
                    icon: const Icon(Icons.hide_source_rounded),
                    tooltip: 'Disable service',
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PricingTab extends StatelessWidget {
  const _PricingTab({
    required this.snapshot,
    required this.services,
    required this.query,
    required this.filter,
    required this.onPricingRule,
  });

  final _CatalogSnapshot snapshot;
  final List<_AdminService> services;
  final String query;
  final _CatalogFilter filter;
  final ValueChanged<_AdminService> onPricingRule;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing management',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Maintain base, city, seasonal, promotional, and worker-level pricing.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...services.map(
          (service) => _CatalogCard(
            title: service.name,
            subtitle:
                'Base price ₹${service.startingPrice.toStringAsFixed(0)} - GST ${service.gstRate.toStringAsFixed(2)}% - SAC ${service.sacCode} - ${service.pricingRules.length} rules',
            tag: 'Pricing',
            accent: AbzioTheme.accentColor,
            onTap: () => context.push('/catalog/services/${service.id}'),
            onEdit: () => onPricingRule(service),
            onDisable: null,
          ),
        ),
      ],
    );
  }
}

class _ImportExportTab extends StatelessWidget {
  const _ImportExportTab({
    required this.onImport,
    required this.onExport,
    required this.onAddStarter,
  });

  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onAddStarter;

  @override
  Widget build(BuildContext context) {
    return ListView(
      primary: true,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import and export',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use JSON import jobs to manage large catalog updates safely.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: onImport,
                child: const Text('Run import'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onExport,
                child: const Text('Export catalog'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAddStarter,
          icon: const Icon(Icons.library_add_outlined),
          label: const Text('Add starter catalog drafts'),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AbzioTheme.lightBorder),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Add, edit, reorder, enable, or disable categories, subcategories, and services. Disabling keeps records attached to existing bookings. JSON import and export are also available for bulk catalog changes.',
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onDisable,
    this.trailing,
    this.imageUrl,
    this.secondaryLabel = 'Disable',
  });

  final String title;
  final String subtitle;
  final String tag;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onDisable;
  final Widget? trailing;
  final String? imageUrl;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VeeduFixCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: VeeduFixDesignSystem.space16,
            vertical: VeeduFixDesignSystem.space8,
          ),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl!.trim().isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.grid_view_rounded, color: accent),
                  )
                : Icon(Icons.grid_view_rounded, color: accent),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _TagChip(label: tag, accent: accent),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle),
          ),
          trailing: trailing ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                    tooltip: 'Edit',
                  ),
                  if (onDisable != null)
                    IconButton(
                      onPressed: onDisable,
                      icon: const Icon(Icons.visibility_off_rounded),
                      tooltip: secondaryLabel,
                    ),
                ],
              ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusMedium),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
      ),
    );
  }
}

class CategoryDetailPage extends ConsumerStatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.categoryId,
  });

  final String categoryId;

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  late final _CatalogAdminApi _api;
  late Future<({_CatalogSnapshot snapshot, _AdminCategory category})?> _future;

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<({_CatalogSnapshot snapshot, _AdminCategory category})?>
      _load() async {
    final snapshot = await _api.fetchSnapshot();
    for (final category in snapshot.categories) {
      if (category.id == widget.categoryId) {
        return (snapshot: snapshot, category: category);
      }
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _showCategoryEditor(
      _AdminCategory existing) async {
    final loaded = await _future;
    if (!mounted || loaded == null) return null;
    final snapshot = loaded.snapshot;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final descriptionController =
        TextEditingController(text: existing.description ?? '');
    String? iconUrl = existing.iconUrl;
    final seoTitleController =
        TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController =
        TextEditingController(text: existing.seoDescription ?? '');
    final sortOrderController =
        TextEditingController(text: existing.sortOrder.toString());
    var featured = existing.featured;
    var popular = existing.popular;
    var isActive = existing.isActive;
    var availabilityMode = existing.availabilityMode;
    final serviceAreaIds = <String>{...existing.serviceAreaIds};

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit ${existing.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a category name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      AdminImagePickerField(
                        label: 'Category image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 800,
                        recommendedHeight: 800,
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration:
                            const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration:
                            const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort order'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: featured,
                        onChanged: (value) => setState(() => featured = value),
                        title: const Text('Featured'),
                      ),
                      SwitchListTile(
                        value: popular,
                        onChanged: (value) => setState(() => popular = value),
                        title: const Text('Popular'),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      _AvailabilitySettingsEditor(
                        snapshot: snapshot,
                        mode: availabilityMode,
                        availabilityKey: existing.id,
                        selectedAreaIds: serviceAreaIds,
                        onModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        inheritedHelp:
                            'Available in every active service area.',
                        onAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'iconUrl': iconUrl,
                      'seoTitle': seoTitleController.text.trim().isEmpty
                          ? null
                          : seoTitleController.text.trim(),
                      'seoDescription':
                          seoDescriptionController.text.trim().isEmpty
                              ? null
                              : seoDescriptionController.text.trim(),
                      'sortOrder':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'isActive': isActive,
                      'availabilityMode': availabilityMode,
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      slugController.dispose();
      descriptionController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      sortOrderController.dispose();
    });
  }

  Future<void> _editCategory(_AdminCategory category) async {
    final payload = await _showCategoryEditor(category);
    if (payload == null) return;
    try {
      await _api.updateCategory(category.id, payload);
      await _reload();
      await _showMessage('Category updated');
    } catch (error) {
      await _showMessage('Unable to update category: $error');
    }
  }

  Future<void> _toggleCategory(_AdminCategory category) async {
    try {
      await _api.updateCategory(category.id, {'isActive': !category.isActive});
      await _reload();
      await _showMessage(
          category.isActive ? 'Category disabled' : 'Category enabled');
    } catch (error) {
      await _showMessage('Unable to update category status: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Category Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
              onPressed: _reload, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: FutureBuilder<
          ({_CatalogSnapshot snapshot, _AdminCategory category})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load category: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text('Category not found',
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This category is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Reload')),
                  ],
                ),
              ),
            );
          }

          final category = data.category;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AbzioTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.category_rounded,
                        color: AbzioTheme.successColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name,
                            style: tt.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(category.slug,
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (!category.isActive) const _DetailBadge(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _editCategory(category),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit category'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleCategory(category),
                    icon: Icon(category.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    label: Text(category.isActive ? 'Disable' : 'Enable'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                      label: category.featured ? 'Featured' : 'Standard'),
                  _DetailChip(
                      label: category.popular ? 'Popular' : 'Not popular'),
                  _DetailChip(
                      label: '${category.subcategories.length} subcategories'),
                  _DetailChip(label: '${category.serviceCount} services'),
                ],
              ),
              const SizedBox(height: 18),
              if ((category.description ?? '').trim().isNotEmpty) ...[
                Text('Description',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(category.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((category.iconUrl ?? '').trim().isNotEmpty) ...[
                _AdminCatalogImagePreview(url: category.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((category.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO title', value: category.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((category.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO description',
                    value: category.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(label: 'Category ID', value: category.id),
              _DetailLine(label: 'Slug', value: category.slug),
              _DetailLine(
                  label: 'Status',
                  value: category.isActive ? 'Active' : 'Disabled'),
              _DetailLine(label: 'Sort order', value: '${category.sortOrder}'),
              const SizedBox(height: 18),
              Text('Subcategories',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...category.subcategories.map(
                (subcategory) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: AbzioTheme.lightMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    title: Text(subcategory.name),
                    subtitle: Text(
                        '${subcategory.services.length} services - ₹${subcategory.basePrice.toStringAsFixed(0)} base'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context
                        .push('/catalog/subcategories/${subcategory.id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SubcategoryDetailPage extends ConsumerStatefulWidget {
  const SubcategoryDetailPage({
    super.key,
    required this.subcategoryId,
  });

  final String subcategoryId;

  @override
  ConsumerState<SubcategoryDetailPage> createState() =>
      _SubcategoryDetailPageState();
}

class _SubcategoryDetailPageState extends ConsumerState<SubcategoryDetailPage> {
  late final _CatalogAdminApi _api;
  late Future<({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?>
      _future;

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?>
      _load() async {
    final snapshot = await _api.fetchSnapshot();
    for (final subcategory in snapshot.subcategories) {
      if (subcategory.id == widget.subcategoryId) {
        return (snapshot: snapshot, subcategory: subcategory);
      }
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _showSubcategoryEditor(
      _CatalogSnapshot snapshot, _AdminSubcategory existing) {
    final formKey = GlobalKey<FormState>();
    final categoryIdController = ValueNotifier<String>(existing.categoryId);
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final descriptionController =
        TextEditingController(text: existing.description ?? '');
    String? iconUrl = existing.iconUrl;
    final seoTitleController =
        TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController =
        TextEditingController(text: existing.seoDescription ?? '');
    final basePriceController =
        TextEditingController(text: existing.basePrice.toStringAsFixed(0));
    final sortOrderController =
        TextEditingController(text: existing.sortOrder.toString());
    final ratingController =
        TextEditingController(text: existing.rating.toStringAsFixed(1));
    final reviewCountController =
        TextEditingController(text: existing.reviewCount.toString());
    var isActive = existing.isActive;
    var availabilityMode = existing.availabilityMode;
    final serviceAreaIds = <String>{...existing.serviceAreaIds};

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Edit ${existing.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: categoryIdController.value.isEmpty
                            ? null
                            : categoryIdController.value,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(
                            () => categoryIdController.value = value ?? ''),
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a subcategory name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      AdminImagePickerField(
                        label: 'Group image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 800,
                        recommendedHeight: 800,
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration:
                            const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration:
                            const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: basePriceController,
                        decoration:
                            const InputDecoration(labelText: 'Base price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration:
                            const InputDecoration(labelText: 'Sort order'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration:
                            const InputDecoration(labelText: 'Review count'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      _AvailabilitySettingsEditor(
                        snapshot: snapshot,
                        mode: availabilityMode,
                        availabilityKey: existing.id,
                        selectedAreaIds: serviceAreaIds,
                        onModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        onAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop({
                      'categoryId': categoryIdController.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'iconUrl': iconUrl,
                      'seoTitle': seoTitleController.text.trim().isEmpty
                          ? null
                          : seoTitleController.text.trim(),
                      'seoDescription':
                          seoDescriptionController.text.trim().isEmpty
                              ? null
                              : seoDescriptionController.text.trim(),
                      'basePrice':
                          double.tryParse(basePriceController.text.trim()) ?? 0,
                      'sortOrder':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'rating':
                          double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount':
                          int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'isActive': isActive,
                      'availabilityMode': availabilityMode,
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      categoryIdController.dispose();
      nameController.dispose();
      slugController.dispose();
      descriptionController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      basePriceController.dispose();
      sortOrderController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
    });
  }

  Future<void> _editSubcategory(
      _CatalogSnapshot snapshot, _AdminSubcategory subcategory) async {
    final payload = await _showSubcategoryEditor(snapshot, subcategory);
    if (payload == null) return;
    try {
      await _api.updateSubcategory(subcategory.id, payload);
      await _reload();
      await _showMessage('Subcategory updated');
    } catch (error) {
      await _showMessage('Unable to update subcategory: $error');
    }
  }

  Future<void> _toggleSubcategory(_AdminSubcategory subcategory) async {
    try {
      await _api.updateSubcategory(
          subcategory.id, {'isActive': !subcategory.isActive});
      await _reload();
      await _showMessage(subcategory.isActive
          ? 'Subcategory disabled'
          : 'Subcategory enabled');
    } catch (error) {
      await _showMessage('Unable to update subcategory status: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subcategory Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
              onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<
          ({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load subcategory: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text('Subcategory not found',
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This subcategory is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Reload')),
                  ],
                ),
              ),
            );
          }

          final subcategory = data.subcategory;
          final category = data.snapshot.categoryById(subcategory.categoryId);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.layers_rounded,
                        color: AbzioTheme.accentColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subcategory.name,
                            style: tt.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(category?.name ?? 'Category',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (!subcategory.isActive)
                    const _DetailBadge(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        _editSubcategory(data.snapshot, subcategory),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit subcategory'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleSubcategory(subcategory),
                    icon: Icon(subcategory.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    label: Text(subcategory.isActive ? 'Disable' : 'Enable'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(label: '${subcategory.services.length} services'),
                  _DetailChip(
                      label:
                          '₹${subcategory.basePrice.toStringAsFixed(0)} base'),
                  _DetailChip(
                      label: 'Rating ${subcategory.rating.toStringAsFixed(1)}'),
                  _DetailChip(label: '${subcategory.reviewCount} reviews'),
                  _DetailChip(
                      label: subcategory.isActive ? 'Active' : 'Disabled'),
                ],
              ),
              const SizedBox(height: 18),
              if ((subcategory.description ?? '').trim().isNotEmpty) ...[
                Text('Description',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subcategory.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((subcategory.iconUrl ?? '').trim().isNotEmpty) ...[
                _AdminCatalogImagePreview(url: subcategory.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((subcategory.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO title', value: subcategory.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((subcategory.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO description',
                    value: subcategory.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(
                  label: 'Rating',
                  value: subcategory.rating.toStringAsFixed(1)),
              _DetailLine(
                  label: 'Review count', value: '${subcategory.reviewCount}'),
              _DetailLine(label: 'Subcategory ID', value: subcategory.id),
              _DetailLine(
                  label: 'Category', value: category?.name ?? 'Unknown'),
              _DetailLine(label: 'Slug', value: subcategory.slug),
              _DetailLine(
                  label: 'Base price',
                  value: '₹${subcategory.basePrice.toStringAsFixed(0)}'),
              _DetailLine(
                  label: 'Status',
                  value: subcategory.isActive ? 'Active' : 'Disabled'),
              _DetailLine(
                  label: 'Sort order', value: '${subcategory.sortOrder}'),
              const SizedBox(height: 18),
              Text('Services',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...subcategory.services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: AbzioTheme.lightMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    title: Text(service.name),
                    subtitle: Text(
                        '₹${service.startingPrice.toStringAsFixed(0)} - ${service.estimatedDurationMins} mins'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () =>
                        context.push('/catalog/services/${service.id}'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ServiceDetailPage extends ConsumerStatefulWidget {
  const ServiceDetailPage({
    super.key,
    required this.serviceId,
  });

  final String serviceId;

  @override
  ConsumerState<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends ConsumerState<ServiceDetailPage> {
  late final _CatalogAdminApi _api;
  late Future<({_CatalogSnapshot snapshot, _AdminService service})?> _future;

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<({_CatalogSnapshot snapshot, _AdminService service})?> _load() async {
    final snapshot = await _api.fetchSnapshot();
    for (final service in snapshot.services) {
      if (service.id == widget.serviceId) {
        return (snapshot: snapshot, service: service);
      }
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _manageServiceImages(_AdminService service) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final images = service.images
            .map((image) => <String, dynamic>{
                  'url': image.url,
                  'altText': image.altText,
                  'isPrimary': image.isPrimary,
                })
            .toList(growable: true);
        var saving = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void moveGalleryImage(int fromIndex, int toIndex) {
              if (saving ||
                  fromIndex < 0 ||
                  fromIndex >= images.length ||
                  toIndex < 0 ||
                  toIndex >= images.length ||
                  fromIndex == toIndex) {
                return;
              }
              setDialogState(() {
                final moved = images.removeAt(fromIndex);
                images.insert(toIndex, moved);
                error = null;
              });
            }

            Future<void> editGalleryImage({int? replaceIndex}) async {
              final current =
                  replaceIndex == null ? null : images[replaceIndex];
              final result = await _showServiceGalleryImagePicker(
                context: context,
                serviceName: service.name,
                current: current,
                uploadImage: (bytes, fileName) async {
                  final response =
                      await _api.uploadCatalogImage(bytes, fileName);
                  final url = response['url'];
                  if (url is! String || !url.startsWith('https://')) {
                    throw StateError(
                        'The image upload returned an invalid URL.');
                  }
                  return url;
                },
              );
              if (result == null) return;
              setDialogState(() {
                if (replaceIndex != null && replaceIndex < images.length) {
                  images[replaceIndex] = result;
                } else {
                  result['isPrimary'] = images.isEmpty;
                  images.add(result);
                }
                error = null;
              });
            }

            return AlertDialog(
              title: Text('Service images · ${service.name}'),
              content: SizedBox(
                width: 720,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                        'Drag to reorder. Choose one primary image for the customer service page.'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : () => editGalleryImage(),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Add gallery image'),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: images.isEmpty
                          ? const Center(
                              child: Text(
                                  'No service images yet. Add images to preview and manage the gallery.'))
                          : LayoutBuilder(
                              builder: (context, constraints) =>
                                  GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      constraints.maxWidth < 520 ? 1 : 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 278,
                                ),
                                itemCount: images.length,
                                itemBuilder: (context, imageIndex) {
                                  final item = images[imageIndex];
                                  final url = item['url'] as String? ?? '';
                                  final isPrimary = item['isPrimary'] == true;
                                  final tile = Card(
                                    margin: EdgeInsets.zero,
                                    clipBehavior: Clip.antiAlias,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.network(url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __,
                                                            ___) =>
                                                        const ColoredBox(
                                                            color: Color(
                                                                0xFFF1EEE7),
                                                            child: Center(
                                                                child: Icon(Icons
                                                                    .broken_image_outlined)))),
                                                Positioned(
                                                  right: 4,
                                                  top: 4,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .surface
                                                            .withValues(
                                                                alpha: 0.9),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20)),
                                                    child: const Padding(
                                                        padding:
                                                            EdgeInsets.all(6),
                                                        child: Icon(
                                                            Icons
                                                                .drag_indicator_rounded,
                                                            size: 18)),
                                                  ),
                                                ),
                                                if (isPrimary)
                                                  const Positioned(
                                                      left: 6,
                                                      top: 6,
                                                      child: Chip(
                                                          label:
                                                              Text('Primary'))),
                                              ],
                                            ),
                                          ),
                                          TextFormField(
                                            initialValue:
                                                item['altText']?.toString() ??
                                                    '',
                                            enabled: !saving,
                                            decoration: const InputDecoration(
                                                labelText: 'Alt text',
                                                isDense: true),
                                            onChanged: (value) =>
                                                item['altText'] = value,
                                          ),
                                          Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              IconButton(
                                                tooltip: 'Move image earlier',
                                                onPressed: saving ||
                                                        imageIndex == 0
                                                    ? null
                                                    : () => moveGalleryImage(
                                                          imageIndex,
                                                          imageIndex - 1,
                                                        ),
                                                icon: const Icon(
                                                  Icons.arrow_upward_rounded,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Move image later',
                                                onPressed: saving ||
                                                        imageIndex ==
                                                            images.length - 1
                                                    ? null
                                                    : () => moveGalleryImage(
                                                          imageIndex,
                                                          imageIndex + 1,
                                                        ),
                                                icon: const Icon(
                                                  Icons.arrow_downward_rounded,
                                                ),
                                              ),
                                              if (!isPrimary)
                                                TextButton.icon(
                                                  onPressed: saving
                                                      ? null
                                                      : () => setDialogState(
                                                            () {
                                                              for (final image
                                                                  in images) {
                                                                image['isPrimary'] =
                                                                    false;
                                                              }
                                                              item['isPrimary'] =
                                                                  true;
                                                            },
                                                          ),
                                                  icon: const Icon(Icons
                                                      .star_border_rounded),
                                                  label:
                                                      const Text('Set primary'),
                                                ),
                                              IconButton(
                                                  tooltip: 'Preview',
                                                  onPressed: () => showDialog<
                                                          void>(
                                                      context: context,
                                                      builder:
                                                          (previewContext) =>
                                                              Dialog(
                                                                child:
                                                                    ConstrainedBox(
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                          maxWidth:
                                                                              520),
                                                                  child:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            20),
                                                                    child:
                                                                        Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                            'Customer preview',
                                                                            style:
                                                                                Theme.of(previewContext).textTheme.titleMedium),
                                                                        const SizedBox(
                                                                            height:
                                                                                10),
                                                                        AspectRatio(
                                                                          aspectRatio:
                                                                              360 / 250,
                                                                          child:
                                                                              ClipRRect(
                                                                            borderRadius:
                                                                                const BorderRadius.vertical(bottom: Radius.circular(22)),
                                                                            child: Image.network(url,
                                                                                fit: BoxFit.cover,
                                                                                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1EEE7), child: Center(child: Icon(Icons.broken_image_outlined)))),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            height:
                                                                                8),
                                                                        const Text(
                                                                            'Customer service hero · 360 × 250 dp · BoxFit.cover'),
                                                                        Align(
                                                                            alignment:
                                                                                Alignment.centerRight,
                                                                            child: TextButton(onPressed: () => Navigator.pop(previewContext), child: const Text('Close'))),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              )),
                                                  icon: const Icon(Icons
                                                      .visibility_outlined)),
                                              IconButton(
                                                  tooltip: 'Replace image',
                                                  onPressed: saving
                                                      ? null
                                                      : () => editGalleryImage(
                                                          replaceIndex:
                                                              imageIndex),
                                                  icon: const Icon(Icons
                                                      .drive_folder_upload_outlined)),
                                              IconButton(
                                                tooltip: 'Remove image',
                                                onPressed: saving
                                                    ? null
                                                    : () async {
                                                        final confirmed = await showDialog<
                                                                bool>(
                                                            context: context,
                                                            builder: (confirmContext) =>
                                                                AlertDialog(
                                                                    title: const Text(
                                                                        'Remove this image?'),
                                                                    content:
                                                                        const Text(
                                                                            'It will be removed from the gallery when you save.'),
                                                                    actions: [
                                                                      TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              confirmContext,
                                                                              false),
                                                                          child:
                                                                              const Text('Cancel')),
                                                                      FilledButton(
                                                                          onPressed: () => Navigator.pop(
                                                                              confirmContext,
                                                                              true),
                                                                          child:
                                                                              const Text('Remove'))
                                                                    ]));
                                                        if (confirmed != true)
                                                          return;
                                                        setDialogState(() {
                                                          final removedPrimary =
                                                              item['isPrimary'] ==
                                                                  true;
                                                          images.removeAt(
                                                              imageIndex);
                                                          if (removedPrimary &&
                                                              images
                                                                  .isNotEmpty) {
                                                            images.first[
                                                                    'isPrimary'] =
                                                                true;
                                                          }
                                                        });
                                                      },
                                                icon: const Icon(Icons
                                                    .delete_outline_rounded),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  return DragTarget<int>(
                                    key: ObjectKey(item),
                                    onAcceptWithDetails: (details) =>
                                        moveGalleryImage(
                                      details.data,
                                      imageIndex,
                                    ),
                                    builder: (context, candidates, _) =>
                                        LongPressDraggable<int>(
                                      data: imageIndex,
                                      feedback: SizedBox(
                                          width: 300,
                                          height: 240,
                                          child: Opacity(
                                              opacity: 0.85, child: tile)),
                                      childWhenDragging:
                                          Opacity(opacity: 0.3, child: tile),
                                      child: DecoratedBox(
                                        decoration: candidates.isEmpty
                                            ? const BoxDecoration()
                                            : BoxDecoration(
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    width: 2),
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                        child: tile,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            if (images.isNotEmpty &&
                                !images.any(
                                    (image) => image['isPrimary'] == true)) {
                              images.first['isPrimary'] = true;
                            }
                            await _api.updateService(service.id, {
                              'images': images
                                  .asMap()
                                  .entries
                                  .map((entry) => {
                                        'url': entry.value['url'],
                                        'altText': (entry.value['altText']
                                                    as String? ??
                                                '')
                                            .trim(),
                                        'sortOrder': entry.key,
                                        'isPrimary':
                                            entry.value['isPrimary'] == true,
                                      })
                                  .toList(growable: false),
                            });
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } catch (saveError) {
                            setDialogState(() {
                              saving = false;
                              error = 'Could not save gallery: $saveError';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save gallery'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      await _reload();
      await _showMessage('Service gallery updated');
    }
  }

  Future<Map<String, dynamic>?> _showServiceEditor(
      _CatalogSnapshot snapshot, _AdminService existing) {
    final formKey = GlobalKey<FormState>();
    final selectedCategoryId = ValueNotifier<String>(existing.categoryId);
    final selectedSubcategoryId = ValueNotifier<String>(existing.subcategoryId);
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final codeController = TextEditingController(text: existing.code ?? '');
    final descriptionController =
        TextEditingController(text: existing.description ?? '');
    final shortDescriptionController =
        TextEditingController(text: existing.shortDescription ?? '');
    final inclusionsController =
        TextEditingController(text: existing.inclusions.join('\n'));
    final exclusionsController =
        TextEditingController(text: existing.exclusions.join('\n'));
    final requiredSkillsController =
        TextEditingController(text: existing.requiredSkills.join('\n'));
    final requiredToolsController =
        TextEditingController(text: existing.requiredTools.join('\n'));
    final requiredDocumentsController =
        TextEditingController(text: existing.requiredDocuments.join('\n'));
    final startingPriceController =
        TextEditingController(text: existing.startingPrice.toStringAsFixed(0));
    final gstRateController =
        TextEditingController(text: existing.gstRate.toStringAsFixed(2));
    final sacCodeController = TextEditingController(text: existing.sacCode);
    final durationController =
        TextEditingController(text: existing.estimatedDurationMins.toString());
    final warrantyController =
        TextEditingController(text: existing.warrantyDays.toString());
    String? iconUrl = existing.iconUrl;
    final seoTitleController =
        TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController =
        TextEditingController(text: existing.seoDescription ?? '');
    final seoKeywordsController =
        TextEditingController(text: existing.seoKeywords ?? '');
    final cancellationPolicyController =
        TextEditingController(text: existing.cancellationPolicy ?? '');
    final warrantyTextController =
        TextEditingController(text: existing.warrantyText ?? '');
    final guaranteeWindowController = TextEditingController(
        text: existing.guaranteeClaimWindowDays.toString());
    final guaranteeCategoriesController = TextEditingController(
        text: existing.guaranteeIssueCategories.join('\n'));
    final guaranteeTermsController =
        TextEditingController(text: existing.guaranteeTerms ?? '');
    final guaranteeExclusionsController =
        TextEditingController(text: existing.guaranteeExclusions ?? '');
    final guaranteeRemediesController = TextEditingController(
        text: existing.guaranteeResolutionTypes.join('\n'));
    bool guaranteeEnabled = existing.guaranteeEnabled;
    bool guaranteeRequiresPartnerReview =
        existing.guaranteeRequiresPartnerReview;
    bool guaranteeEvidenceRequired = existing.guaranteeEvidenceRequired;
    final requirementsController =
        TextEditingController(text: existing.requirements.join('\n'));
    final variantsController = TextEditingController(
      text: _formatServiceOptions(existing.variants),
    );
    final addonsController = TextEditingController(
      text: _formatServiceOptions(existing.addons),
    );
    final variantImageUrls = <String, String?>{
      for (final option in existing.variants)
        option.name.trim().toLowerCase(): option.imageUrl,
    };
    final addonImageUrls = <String, String?>{
      for (final option in existing.addons)
        option.name.trim().toLowerCase(): option.imageUrl,
    };
    final existingVariants = existing.variants;
    final variantAvailabilityModes = <String, String>{
      for (final entry in existingVariants.asMap().entries)
        _variantAvailabilityKey(existingVariants, entry.key, entry.value.name):
            entry.value.availabilityMode,
    };
    final variantServiceAreaIds = <String, Set<String>>{
      for (final entry in existingVariants.asMap().entries)
        _variantAvailabilityKey(existingVariants, entry.key, entry.value.name):
            {...entry.value.serviceAreaIds},
    };
    final ctaLabelController = TextEditingController(text: existing.ctaLabel);
    final ratingController =
        TextEditingController(text: existing.rating.toStringAsFixed(2));
    final reviewCountController =
        TextEditingController(text: existing.reviewCount.toString());
    final maintenanceIntervalsController = TextEditingController(
      text: existing.maintenanceIntervalsMonths.join(', '),
    );
    final maintenanceReminderController = TextEditingController(
      text: existing.maintenanceReminderHours.toString(),
    );
    var featured = existing.featured;
    var popular = existing.popular;
    var emergency = existing.emergencyAvailable;
    var homeVisit = existing.homeVisit;
    var requiresSiteVisit = existing.requiresSiteVisit;
    var isActive = existing.isActive;
    var bookingEnabled = existing.bookingEnabled;
    var maintenanceEnabled = existing.maintenanceEnabled;
    var gstApplicable = existing.gstApplicable;
    var priceType = existing.priceType;
    var publicationStatus = existing.publicationStatus;
    DateTime? publishStartsAt = existing.publishStartsAt;
    DateTime? publishEndsAt = existing.publishEndsAt;
    var availabilityMode = existing.availabilityMode;
    final serviceAreaIds = <String>{...existing.serviceAreaIds};
    String? publicationDateError;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategories =
                snapshot.subcategoriesForCategory(selectedCategoryId.value);
            if (subcategories.isNotEmpty &&
                !subcategories
                    .any((item) => item.id == selectedSubcategoryId.value)) {
              selectedSubcategoryId.value = subcategories.first.id;
            }

            return AlertDialog(
              title: Text('Edit ${existing.name}'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId.value.isEmpty
                            ? null
                            : selectedCategoryId.value,
                        decoration:
                            const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setState(() {
                            selectedCategoryId.value = value ?? '';
                            final next = snapshot.subcategoriesForCategory(
                                selectedCategoryId.value);
                            selectedSubcategoryId.value =
                                next.firstOrNull?.id ?? '';
                          });
                        },
                        validator: (value) =>
                            (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubcategoryId.value.isEmpty
                            ? null
                            : selectedSubcategoryId.value,
                        decoration:
                            const InputDecoration(labelText: 'Subcategory'),
                        items: subcategories
                            .map(
                              (subcategory) => DropdownMenuItem(
                                value: subcategory.id,
                                child: Text(subcategory.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(
                            () => selectedSubcategoryId.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty
                            ? 'Select a subcategory'
                            : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2
                            ? 'Enter a service name'
                            : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(labelText: 'Code'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: shortDescriptionController,
                        decoration: const InputDecoration(
                            labelText: 'Short description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: inclusionsController,
                        decoration: const InputDecoration(
                          labelText: 'What’s included',
                          helperText: 'One item per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: exclusionsController,
                        decoration: const InputDecoration(
                          labelText: 'What’s not included',
                          helperText: 'One item per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: requiredSkillsController,
                        decoration: const InputDecoration(
                          labelText: 'Required skills',
                          helperText: 'One skill per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: requiredToolsController,
                        decoration: const InputDecoration(
                          labelText: 'Required tools',
                          helperText: 'One tool per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: requiredDocumentsController,
                        decoration: const InputDecoration(
                          labelText: 'Required documents',
                          helperText: 'One document per line.',
                        ),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: startingPriceController,
                        decoration:
                            const InputDecoration(labelText: 'Starting price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: gstRateController,
                        decoration:
                            const InputDecoration(labelText: 'GST rate'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: gstApplicable,
                        onChanged: (value) =>
                            setState(() => gstApplicable = value),
                        title: const Text('GST applicable'),
                      ),
                      TextFormField(
                        controller: sacCodeController,
                        decoration:
                            const InputDecoration(labelText: 'SAC code'),
                      ),
                      TextFormField(
                        controller: durationController,
                        decoration:
                            const InputDecoration(labelText: 'Duration (mins)'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyController,
                        decoration:
                            const InputDecoration(labelText: 'Warranty days'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyTextController,
                        decoration: const InputDecoration(
                            labelText: 'Warranty terms (optional)'),
                        maxLines: 3,
                      ),
                      const Divider(height: 28),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: guaranteeEnabled,
                          onChanged: (value) =>
                              setState(() => guaranteeEnabled = value),
                          title: const Text('Enable service guarantee claims'),
                          subtitle: const Text(
                              'Only enable after business policy approval; no remedy is automatic.')),
                      if (guaranteeEnabled) ...[
                        TextFormField(
                            controller: guaranteeWindowController,
                            decoration: const InputDecoration(
                                labelText:
                                    'Claim window after completion (days)'),
                            keyboardType: TextInputType.number),
                        TextFormField(
                            controller: guaranteeCategoriesController,
                            decoration: const InputDecoration(
                                labelText: 'Eligible issue categories',
                                helperText: 'One per line'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeTermsController,
                            decoration: const InputDecoration(
                                labelText: 'Guarantee terms'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeExclusionsController,
                            decoration: const InputDecoration(
                                labelText: 'Guarantee exclusions'),
                            maxLines: 3),
                        TextFormField(
                            controller: guaranteeRemediesController,
                            validator: _validateGuaranteeRemedies,
                            decoration: const InputDecoration(
                                labelText: 'Permitted resolution types',
                                helperText:
                                    'REWORK, REVISIT, REFUND_REVIEW; one per line'),
                            maxLines: 3),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: guaranteeRequiresPartnerReview,
                            onChanged: (value) => setState(
                                () => guaranteeRequiresPartnerReview = value),
                            title: const Text(
                                'Request Partner response during review')),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: guaranteeEvidenceRequired,
                            onChanged: (value) => setState(
                                () => guaranteeEvidenceRequired = value),
                            title: const Text('Require supporting photos')),
                      ],
                      TextFormField(
                        controller: requirementsController,
                        decoration: const InputDecoration(
                          labelText: 'Before booking requirements',
                          helperText: 'One requirement per line.',
                        ),
                        maxLines: 4,
                      ),
                      TextFormField(
                        controller: variantsController,
                        decoration: const InputDecoration(
                          labelText: 'Service options / variants',
                          helperText:
                              'One per line: name | price | duration minutes | active/inactive | description',
                        ),
                        maxLines: 4,
                        validator: _validateServiceOptionLines,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildServiceOptionImageEditors(
                        context: context,
                        controller: variantsController,
                        selectedImageUrls: variantImageUrls,
                        label: 'Variant images',
                        setState: setState,
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                      ),
                      _buildServiceOptionAvailabilityEditors(
                        context: context,
                        snapshot: snapshot,
                        controller: variantsController,
                        existingVariants: existingVariants,
                        modes: variantAvailabilityModes,
                        areaIds: variantServiceAreaIds,
                        setState: setState,
                      ),
                      TextFormField(
                        controller: addonsController,
                        decoration: const InputDecoration(
                          labelText: 'Optional add-ons',
                          helperText:
                              'One per line: name | price | duration minutes | active/inactive | description',
                        ),
                        maxLines: 4,
                        validator: _validateServiceOptionLines,
                        onChanged: (_) => setState(() {}),
                      ),
                      _buildServiceOptionImageEditors(
                        context: context,
                        controller: addonsController,
                        selectedImageUrls: addonImageUrls,
                        label: 'Add-on images',
                        setState: setState,
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                      ),
                      _buildPublicationControls(
                        context: context,
                        snapshot: snapshot,
                        publicationStatus: publicationStatus,
                        availabilityMode: availabilityMode,
                        availabilityKey: existing.id,
                        publishStartsAt: publishStartsAt,
                        publishEndsAt: publishEndsAt,
                        serviceAreaIds: serviceAreaIds,
                        dateError: publicationDateError,
                        onPublicationStatusChanged: (value) =>
                            setState(() => publicationStatus = value),
                        onAvailabilityModeChanged: (value) =>
                            setState(() => availabilityMode = value),
                        onPublishStartsAtChanged: (value) => setState(() {
                          publishStartsAt = value;
                          publicationDateError = null;
                        }),
                        onPublishEndsAtChanged: (value) => setState(() {
                          publishEndsAt = value;
                          publicationDateError = null;
                        }),
                        onServiceAreaToggled: (id) => setState(() {
                          if (!serviceAreaIds.add(id)) {
                            serviceAreaIds.remove(id);
                          }
                        }),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: priceType,
                        decoration: const InputDecoration(
                            labelText: 'Customer price label'),
                        items: const [
                          DropdownMenuItem(
                              value: 'FIXED', child: Text('Fixed price')),
                          DropdownMenuItem(
                              value: 'FROM', child: Text('Starting from')),
                          DropdownMenuItem(
                              value: 'QUOTE',
                              child: Text('Price after assessment')),
                        ],
                        onChanged: (value) =>
                            setState(() => priceType = value ?? 'FROM'),
                      ),
                      TextFormField(
                        controller: ctaLabelController,
                        decoration: const InputDecoration(
                            labelText: 'Booking button text'),
                        maxLength: 40,
                      ),
                      AdminImagePickerField(
                        label: 'Service image',
                        value: iconUrl,
                        onChanged: (value) => setState(() => iconUrl = value),
                        uploadImage: (bytes, fileName) =>
                            _uploadCatalogImage(_api, bytes, fileName),
                        recommendedWidth: 1200,
                        recommendedHeight: 840,
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration:
                            const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration:
                            const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: seoKeywordsController,
                        decoration: const InputDecoration(
                          labelText: 'Search aliases / SEO keywords',
                          helperText:
                              'Comma-separated service names and phrases customers may search for.',
                        ),
                      ),
                      TextFormField(
                        controller: cancellationPolicyController,
                        decoration: const InputDecoration(
                            labelText: 'Cancellation policy'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration:
                            const InputDecoration(labelText: 'Review count'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: featured,
                        onChanged: (value) => setState(() => featured = value),
                        title: const Text('Featured'),
                      ),
                      SwitchListTile(
                        value: popular,
                        onChanged: (value) => setState(() => popular = value),
                        title: const Text('Popular'),
                      ),
                      SwitchListTile(
                        value: emergency,
                        onChanged: (value) => setState(() => emergency = value),
                        title: const Text('Emergency available'),
                      ),
                      SwitchListTile(
                        value: homeVisit,
                        onChanged: (value) => setState(() => homeVisit = value),
                        title: const Text('Home visit'),
                      ),
                      SwitchListTile(
                        value: requiresSiteVisit,
                        onChanged: (value) =>
                            setState(() => requiresSiteVisit = value),
                        title: const Text('Requires site visit (Big Job)'),
                        subtitle: const Text(
                            'Worker visits first to generate a custom quote'),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
                      ),
                      SwitchListTile(
                        value: bookingEnabled,
                        onChanged: (value) =>
                            setState(() => bookingEnabled = value),
                        title: const Text('Booking enabled'),
                        subtitle: const Text(
                            'Disable temporarily without hiding the service.'),
                      ),
                      SwitchListTile(
                        value: maintenanceEnabled,
                        onChanged: (value) =>
                            setState(() => maintenanceEnabled = value),
                        title: const Text('Recurring maintenance plans'),
                        subtitle: const Text(
                            'Every visit remains customer-confirmed and uses checkout.'),
                      ),
                      if (maintenanceEnabled) ...[
                        TextFormField(
                          controller: maintenanceIntervalsController,
                          decoration: const InputDecoration(
                              labelText: 'Allowed intervals (months)',
                              hintText: '1, 3, 6, 12'),
                          validator: (value) {
                            if (!maintenanceEnabled) return null;
                            final tokens = (value ?? '')
                                .split(',')
                                .map((item) => item.trim())
                                .where((item) => item.isNotEmpty)
                                .toList();
                            final values = tokens
                                .map((item) => int.tryParse(item))
                                .whereType<int>()
                                .toList();
                            if (tokens.isEmpty ||
                                values.length != tokens.length ||
                                values.any((item) => item < 1 || item > 24) ||
                                values.toSet().length != values.length) {
                              return 'Enter unique month intervals from 1 to 24.';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: maintenanceReminderController,
                          decoration: const InputDecoration(
                              labelText: 'Reminder lead time (hours)'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (!maintenanceEnabled) return null;
                            final hours = int.tryParse(value ?? '');
                            return hours == null || hours < 1 || hours > 720
                                ? 'Enter 1 to 720 hours.'
                                : null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    if (_customAvailabilityHasNoLocations(
                      availabilityMode,
                      serviceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(dialogContext);
                      return;
                    }
                    if (_hasUncoveredCustomVariant(
                      variantsController.text,
                      existingVariants,
                      variantAvailabilityModes,
                      variantServiceAreaIds,
                    )) {
                      _showCustomAvailabilityValidationError(
                        dialogContext,
                        isVariant: true,
                      );
                      return;
                    }
                    if (publishStartsAt != null &&
                        publishEndsAt != null &&
                        !publishEndsAt!.isAfter(publishStartsAt!)) {
                      setState(() => publicationDateError =
                          'End date must be after the start date.');
                      return;
                    }
                    Navigator.of(dialogContext).pop({
                      'categoryId': selectedCategoryId.value,
                      'subcategoryId': selectedSubcategoryId.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty
                          ? _slugify(nameController.text)
                          : slugController.text.trim(),
                      'code': codeController.text.trim().isEmpty
                          ? null
                          : codeController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'shortDescription':
                          shortDescriptionController.text.trim().isEmpty
                              ? null
                              : shortDescriptionController.text.trim(),
                      'startingPrice': double.tryParse(
                              startingPriceController.text.trim()) ??
                          0,
                      'gstRate':
                          double.tryParse(gstRateController.text.trim()) ?? 18,
                      'sacCode': sacCodeController.text.trim().isEmpty
                          ? 'PENDING'
                          : sacCodeController.text.trim(),
                      'estimatedDurationMins':
                          int.tryParse(durationController.text.trim()) ?? 0,
                      'warrantyDays':
                          int.tryParse(warrantyController.text.trim()) ?? 0,
                      'inclusions': _serviceLines(inclusionsController.text),
                      'exclusions': _serviceLines(exclusionsController.text),
                      'requiredSkills': _serviceRequirementRows(
                          requiredSkillsController.text),
                      'requiredTools':
                          _serviceRequirementRows(requiredToolsController.text),
                      'requiredDocuments': _serviceRequirementRows(
                          requiredDocumentsController.text),
                      'warrantyText': warrantyTextController.text.trim().isEmpty
                          ? null
                          : warrantyTextController.text.trim(),
                      'guaranteeEnabled': guaranteeEnabled,
                      'guaranteeClaimWindowDays': guaranteeEnabled
                          ? (int.tryParse(
                                  guaranteeWindowController.text.trim()) ??
                              0)
                          : 0,
                      'guaranteeIssueCategories':
                          _serviceLines(guaranteeCategoriesController.text),
                      'guaranteeTerms':
                          guaranteeTermsController.text.trim().isEmpty
                              ? null
                              : guaranteeTermsController.text.trim(),
                      'guaranteeExclusions':
                          guaranteeExclusionsController.text.trim().isEmpty
                              ? null
                              : guaranteeExclusionsController.text.trim(),
                      'guaranteeResolutionTypes':
                          _serviceLines(guaranteeRemediesController.text)
                              .map((value) => value.toUpperCase())
                              .toList(growable: false),
                      'guaranteeRequiresPartnerReview':
                          guaranteeRequiresPartnerReview,
                      'guaranteeEvidenceRequired': guaranteeEvidenceRequired,
                      'requirements': requirementsController.text
                          .split('\n')
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList(growable: false),
                      'variants': _serviceOptionRows(
                        variantsController.text,
                        existing.variants,
                        isVariant: true,
                        imageUrls: variantImageUrls,
                        availabilityModes: variantAvailabilityModes,
                        serviceAreaIds: variantServiceAreaIds,
                      ),
                      'addons': _serviceOptionRows(
                        addonsController.text,
                        existing.addons,
                        isVariant: false,
                        imageUrls: addonImageUrls,
                      ),
                      'priceType': priceType,
                      'ctaLabel': ctaLabelController.text.trim().isEmpty
                          ? 'Book service'
                          : ctaLabelController.text.trim(),
                      'iconUrl': iconUrl,
                      'seoTitle': seoTitleController.text.trim().isEmpty
                          ? null
                          : seoTitleController.text.trim(),
                      'seoDescription':
                          seoDescriptionController.text.trim().isEmpty
                              ? null
                              : seoDescriptionController.text.trim(),
                      'seoKeywords': seoKeywordsController.text.trim().isEmpty
                          ? null
                          : seoKeywordsController.text.trim(),
                      'cancellationPolicy':
                          cancellationPolicyController.text.trim().isEmpty
                              ? null
                              : cancellationPolicyController.text.trim(),
                      'rating':
                          double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount':
                          int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'emergencyAvailable': emergency,
                      'gstApplicable': gstApplicable,
                      'homeVisit': homeVisit,
                      'requiresSiteVisit': requiresSiteVisit,
                      'isActive': isActive,
                      'bookingEnabled': bookingEnabled,
                      'maintenanceEnabled': maintenanceEnabled,
                      'maintenanceIntervalsMonths': maintenanceEnabled
                          ? maintenanceIntervalsController.text
                              .split(',')
                              .map((item) => int.tryParse(item.trim()))
                              .whereType<int>()
                              .toList()
                          : <int>[],
                      'maintenanceReminderHours': int.tryParse(
                              maintenanceReminderController.text.trim()) ??
                          24,
                      'publicationStatus': publicationStatus,
                      'publishStartsAt':
                          publishStartsAt?.toUtc().toIso8601String(),
                      'publishEndsAt': publishEndsAt?.toUtc().toIso8601String(),
                      'serviceAreaIds': availabilityMode == 'CUSTOM'
                          ? serviceAreaIds.toList(growable: false)
                          : const <String>[],
                      'availabilityMode': availabilityMode,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      selectedCategoryId.dispose();
      selectedSubcategoryId.dispose();
      nameController.dispose();
      slugController.dispose();
      codeController.dispose();
      descriptionController.dispose();
      shortDescriptionController.dispose();
      inclusionsController.dispose();
      exclusionsController.dispose();
      requiredSkillsController.dispose();
      requiredToolsController.dispose();
      requiredDocumentsController.dispose();
      startingPriceController.dispose();
      gstRateController.dispose();
      sacCodeController.dispose();
      durationController.dispose();
      warrantyController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      seoKeywordsController.dispose();
      cancellationPolicyController.dispose();
      warrantyTextController.dispose();
      guaranteeWindowController.dispose();
      guaranteeCategoriesController.dispose();
      guaranteeTermsController.dispose();
      guaranteeExclusionsController.dispose();
      guaranteeRemediesController.dispose();
      requirementsController.dispose();
      variantsController.dispose();
      addonsController.dispose();
      ctaLabelController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
      maintenanceIntervalsController.dispose();
      maintenanceReminderController.dispose();
    });
  }

  Future<void> _editService(
      _CatalogSnapshot snapshot, _AdminService service) async {
    final payload = await _showServiceEditor(snapshot, service);
    if (payload == null) return;
    try {
      await _api.updateService(service.id, payload);
      await _reload();
      await _showMessage('Service updated');
    } catch (error) {
      await _showMessage('Unable to update service: $error');
    }
  }

  Future<void> _toggleService(_AdminService service) async {
    try {
      await _api.updateService(service.id, {'isActive': !service.isActive});
      await _reload();
      await _showMessage(
          service.isActive ? 'Service disabled' : 'Service enabled');
    } catch (error) {
      await _showMessage('Unable to update service status: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Service Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
              onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body:
          FutureBuilder<({_CatalogSnapshot snapshot, _AdminService service})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Unable to load service: ${snapshot.error}'));
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text('Service not found',
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This service is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Reload')),
                  ],
                ),
              ),
            );
          }

          final service = data.service;
          final category = data.snapshot.categoryById(service.categoryId);
          final subcategory =
              data.snapshot.subcategoryById(service.subcategoryId);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: service.featured
                          ? AbzioTheme.accentColor.withValues(alpha: 0.12)
                          : AbzioTheme.successColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.design_services_rounded,
                      color: service.featured
                          ? AbzioTheme.accentColor
                          : AbzioTheme.successColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.name,
                            style: tt.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(
                            '${category?.name ?? 'Category'} / ${subcategory?.name ?? 'Subcategory'}',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (!service.isActive) const _DetailBadge(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(
                      label: '₹${service.startingPrice.toStringAsFixed(0)}'),
                  _DetailChip(label: '${service.estimatedDurationMins} mins'),
                  _DetailChip(
                      label: 'GST ${service.gstRate.toStringAsFixed(2)}%'),
                  _DetailChip(label: 'SAC ${service.sacCode}'),
                  _DetailChip(
                      label: 'Rating ${service.rating.toStringAsFixed(1)}'),
                  _DetailChip(label: '${service.reviewCount} reviews'),
                  _DetailChip(label: service.isActive ? 'Active' : 'Disabled'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _editService(data.snapshot, service),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit service'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleService(service),
                    icon: Icon(service.isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    label: Text(service.isActive ? 'Disable' : 'Enable'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _manageServiceImages(service),
                    icon: const Icon(Icons.collections_outlined),
                    label: Text('Manage images (${service.images.length})'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (service.images.isNotEmpty) ...[
                Text('Service gallery',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: service.images
                      .map((image) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  image.url,
                                  width: 132,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                      width: 132,
                                      height: 96,
                                      child: Icon(Icons.broken_image_outlined)),
                                ),
                              ),
                              if (image.isPrimary)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surface,
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: const Text('Primary',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ))
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
              ],
              if ((service.description ?? '').trim().isNotEmpty) ...[
                Text('Description',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(service.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((service.shortDescription ?? '').trim().isNotEmpty) ...[
                Text('Short Description',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(service.shortDescription!.trim()),
                const SizedBox(height: 18),
              ],
              if ((service.iconUrl ?? '').trim().isNotEmpty) ...[
                _AdminCatalogImagePreview(url: service.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO title', value: service.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'SEO description',
                    value: service.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoKeywords ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'Search aliases',
                    value: service.seoKeywords!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.cancellationPolicy ?? '').trim().isNotEmpty) ...[
                _DetailLine(
                    label: 'Cancellation policy',
                    value: service.cancellationPolicy!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(
                  label: 'Rating', value: service.rating.toStringAsFixed(1)),
              _DetailLine(
                  label: 'Review count', value: '${service.reviewCount}'),
              _DetailLine(label: 'Service ID', value: service.id),
              _DetailLine(
                  label: 'Category', value: category?.name ?? 'Unknown'),
              _DetailLine(
                  label: 'Subcategory', value: subcategory?.name ?? 'Unknown'),
              _DetailLine(label: 'Slug', value: service.slug),
              _DetailLine(label: 'Code', value: service.code ?? 'None'),
              _DetailLine(
                  label: 'Duration',
                  value: '${service.estimatedDurationMins} mins'),
              _DetailLine(
                  label: 'Home visit', value: service.homeVisit ? 'Yes' : 'No'),
              _DetailLine(
                  label: 'Featured', value: service.featured ? 'Yes' : 'No'),
              _DetailLine(
                  label: 'Status',
                  value: service.isActive ? 'Active' : 'Disabled'),
              const SizedBox(height: 18),
              Text('Pricing Rules',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (service.pricingRules.isEmpty)
                Text('No pricing rules configured yet.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
              else
                ...service.pricingRules.map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AbzioTheme.lightMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AbzioTheme.lightBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(rule.title,
                                    style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800)),
                              ),
                              _DetailChip(label: rule.type),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('₹${rule.price.toStringAsFixed(0)}'),
                          const SizedBox(height: 4),
                          Text('Currency: ${rule.currency}'),
                          const SizedBox(height: 4),
                          Text('Priority: ${rule.priority}'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AbzioTheme.lightMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AbzioTheme.lightBorder),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AbzioTheme.lightTextSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load catalog',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Check the API connection and try again.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogAdminApi {
  _CatalogAdminApi(this._dio);

  final Dio _dio;

  Future<_CatalogSnapshot> fetchSnapshot() async {
    final response = await exportCatalog();
    final rawCategories = (response['categories'] as List?) ?? const [];
    final categories = rawCategories
        .whereType<Map<String, dynamic>>()
        .map(_AdminCategory.fromDetail)
        .toList(growable: false);
    final serviceAreas = (response['serviceAreas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_AdminCatalogServiceArea.fromJson)
        .toList(growable: false);
    return _CatalogSnapshot(categories: categories, serviceAreas: serviceAreas);
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _dio.post('/admin/catalog/categories', data: data);
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    await _dio.patch('/admin/catalog/categories/$id', data: data);
  }

  Future<void> deleteCategory(String id) async {
    await _dio.delete('/admin/catalog/categories/$id', data: const {});
  }

  Future<void> reorderCategories(List<String> ids) async {
    await _dio.post('/admin/catalog/categories/reorder', data: {'ids': ids});
  }

  Future<void> reorderSubcategories(String categoryId, List<String> ids) async {
    await _dio.post('/admin/catalog/subcategories/reorder', data: {
      'categoryId': categoryId,
      'ids': ids,
    });
  }

  Future<void> createSubcategory(Map<String, dynamic> data) async {
    await _dio.post('/admin/catalog/subcategories', data: data);
  }

  Future<void> updateSubcategory(String id, Map<String, dynamic> data) async {
    await _dio.patch('/admin/catalog/subcategories/$id', data: data);
  }

  Future<void> deleteSubcategory(String id) async {
    await _dio.delete('/admin/catalog/subcategories/$id', data: const {});
  }

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
    final response = await _dio
        .post<Map<String, dynamic>>('/admin/catalog/services', data: data);
    return response.data ?? <String, dynamic>{};
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _dio.patch('/admin/catalog/services/$id', data: data);
  }

  Future<void> deleteService(String id) async {
    await _dio.delete('/admin/catalog/services/$id', data: const {});
  }

  Future<void> reorderServices(String subcategoryId, List<String> ids) async {
    await _dio.post('/admin/catalog/services/reorder', data: {
      'subcategoryId': subcategoryId,
      'ids': ids,
    });
  }

  Future<void> addPricingRule(
      String serviceId, Map<String, dynamic> data) async {
    await _dio.post('/admin/catalog/services/$serviceId/pricing-rules',
        data: data);
  }

  Future<void> addServiceImages(
      String serviceId, List<Map<String, dynamic>> images) async {
    await _dio.post('/admin/catalog/services/$serviceId/images',
        data: {'images': images});
  }

  Future<Map<String, dynamic>> uploadCatalogImage(
      Uint8List bytes, String fileName) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/media/catalog',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      }),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> exportCatalog() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/admin/catalog/export');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> importCatalog(List<dynamic> categories) async {
    await _dio.post('/admin/catalog/import', data: {'categories': categories});
  }

  Future<Map<String, dynamic>> bulkSetActiveStatus({
    required String entityType,
    required List<String> ids,
    required bool isActive,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/catalog/bulk-status',
      data: {'entityType': entityType, 'ids': ids, 'isActive': isActive},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> bulkUpdateAvailability(
      Map<String, dynamic> data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/catalog/availability/bulk',
      data: data,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addStarterCatalog() async {
    final response =
        await _dio.post<Map<String, dynamic>>('/admin/catalog/starter');
    return response.data ?? <String, dynamic>{};
  }
}

class _CatalogSnapshot {
  const _CatalogSnapshot(
      {required this.categories, this.serviceAreas = const []});

  const _CatalogSnapshot.empty()
      : categories = const [],
        serviceAreas = const [];

  final List<_AdminCategory> categories;
  final List<_AdminCatalogServiceArea> serviceAreas;

  List<_AdminSubcategory> get subcategories => categories
      .expand((category) => category.subcategories)
      .toList(growable: false);

  List<_AdminService> get services => subcategories
      .expand((subcategory) => subcategory.services)
      .toList(growable: false);

  _AdminCategory? categoryById(String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  _AdminSubcategory? subcategoryById(String id) {
    for (final subcategory in subcategories) {
      if (subcategory.id == id) return subcategory;
    }
    return null;
  }

  List<_AdminSubcategory> subcategoriesForCategory(String categoryId) {
    final category = categoryById(categoryId);
    if (category == null) return const [];
    return category.subcategories;
  }

  List<_AdminService> servicesForSubcategory(String subcategoryId) {
    return subcategoryById(subcategoryId)?.services ?? const [];
  }
}

class _CatalogLocationFilterBar extends StatelessWidget {
  const _CatalogLocationFilterBar({
    required this.snapshot,
    required this.categoryId,
    required this.stateId,
    required this.districtId,
    required this.cityId,
    required this.areaId,
    required this.pincode,
    required this.subcategoryId,
    required this.serviceId,
    required this.availability,
    required this.onChanged,
    required this.onClear,
  });

  final _CatalogSnapshot snapshot;
  final String categoryId;
  final String stateId;
  final String districtId;
  final String cityId;
  final String areaId;
  final String pincode;
  final String subcategoryId;
  final String serviceId;
  final String availability;
  final void Function(String key, String value) onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final locationFilters = _effectiveCatalogLocationFilters(
      snapshot,
      stateId: stateId,
      districtId: districtId,
      cityId: cityId,
      areaId: areaId,
      pincode: pincode,
    );
    final stateAreas = snapshot.serviceAreas
        .where((area) =>
            area.isActive && area.cityIsActive && area.stateId.isNotEmpty)
        .toList(growable: false);
    final districtAreas = stateAreas.where((area) =>
        locationFilters.stateId == 'all' ||
        area.stateId == locationFilters.stateId);
    final cityAreas = districtAreas.where((area) =>
        locationFilters.districtId == 'all' ||
        area.districtId == locationFilters.districtId);
    final selectedCityAreas = cityAreas.where((area) =>
        locationFilters.cityId == 'all' ||
        area.cityId == locationFilters.cityId);
    final stateOptions = _uniqueOptions(
        stateAreas.map((area) => (area.stateId, area.stateName)));
    final districtOptions = _uniqueOptions(
        districtAreas.map((area) => (area.districtId, area.districtName)));
    final cityOptions =
        _uniqueOptions(cityAreas.map((area) => (area.cityId, area.cityName)));
    final areaOptions =
        _uniqueOptions(selectedCityAreas.map((area) => (area.id, area.name)));
    final pincodeAreas = selectedCityAreas.where(
      (area) =>
          locationFilters.areaId == 'all' || area.id == locationFilters.areaId,
    );
    final pincodeOptions = _uniqueOptions(pincodeAreas
        .expand((area) => area.pincodes.map((code) => (code, code))));
    final subcategories = snapshot.subcategories
        .where((item) => categoryId == 'all' || item.categoryId == categoryId)
        .toList(growable: false);
    final services = snapshot.services
        .where((item) =>
            (categoryId == 'all' || item.categoryId == categoryId) &&
            (subcategoryId == 'all' || item.subcategoryId == subcategoryId))
        .toList(growable: false);

    Widget selector(String key, String label, String selected,
        List<(String, String)> values, String allLabel) {
      final entries = _uniqueOptions(values);
      final validSelected =
          selected == 'all' || entries.any((entry) => entry.$1 == selected);
      final effectiveSelected = validSelected ? selected : 'all';
      return SizedBox(
        width: 172,
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key:$effectiveSelected'),
          initialValue: effectiveSelected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            DropdownMenuItem(value: 'all', child: Text(allLabel)),
            ...entries.map((entry) => DropdownMenuItem(
                  value: entry.$1,
                  child: Text(entry.$2, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (value) => onChanged(key, value ?? 'all'),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        selector(
          'state',
          'State',
          locationFilters.stateId,
          stateOptions,
          'All states',
        ),
        selector(
          'district',
          'District',
          locationFilters.districtId,
          districtOptions,
          'All districts',
        ),
        selector(
          'city',
          'City',
          locationFilters.cityId,
          cityOptions,
          'All cities',
        ),
        selector(
          'area',
          'Area',
          locationFilters.areaId,
          areaOptions,
          'All areas',
        ),
        selector(
          'pincode',
          'Pincode',
          locationFilters.pincode,
          pincodeOptions,
          'All pincodes',
        ),
        selector(
            'subcategory',
            'Subcategory',
            subcategoryId,
            subcategories.map((item) => (item.id, item.name)).toList(),
            'All subcategories'),
        selector(
            'service',
            'Service',
            serviceId,
            services.map((item) => (item.id, item.name)).toList(),
            'All services'),
        selector(
            'availability',
            'Availability',
            availability,
            const [
              ('INHERITED', 'Inherited'),
              ('CUSTOM', 'Custom'),
              ('AVAILABLE', 'Available here'),
              ('UNAVAILABLE', 'Unavailable here'),
            ],
            'Any availability'),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear_rounded),
          label: const Text('Clear location filters'),
        ),
      ],
    );
  }

  static List<(String, String)> _uniqueOptions(
      Iterable<(String, String)> values) {
    final unique = <String, String>{};
    for (final (id, name) in values) {
      if (id.isNotEmpty && name.isNotEmpty) unique[id] = name;
    }
    return unique.entries
        .map((entry) => (entry.key, entry.value))
        .toList(growable: false)
      ..sort((left, right) => left.$2.compareTo(right.$2));
  }
}

Future<String> _uploadCatalogImage(
  _CatalogAdminApi api,
  Uint8List bytes,
  String fileName,
) async {
  final result = await api.uploadCatalogImage(bytes, fileName);
  final url = result['url'];
  if (url is! String || !url.startsWith('https://')) {
    throw StateError('The image upload returned an invalid URL.');
  }
  return url;
}

class _AdminCatalogImagePreview extends StatelessWidget {
  const _AdminCatalogImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 72,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 72,
              height: 56,
              child: Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Image selected'),
      ],
    );
  }
}

class _AdminCatalogServiceArea {
  const _AdminCatalogServiceArea({
    required this.id,
    required this.name,
    required this.cityId,
    required this.cityName,
    required this.stateId,
    required this.stateName,
    required this.districtId,
    required this.districtName,
    required this.pincodes,
    required this.isActive,
    required this.cityIsActive,
  });

  final String id;
  final String name;
  final String cityId;
  final String cityName;
  final String stateId;
  final String stateName;
  final String districtId;
  final String districtName;
  final List<String> pincodes;
  final bool isActive;
  final bool cityIsActive;

  factory _AdminCatalogServiceArea.fromJson(Map<String, dynamic> json) {
    final city = json['city'] is Map<String, dynamic>
        ? json['city'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final stateId = (city['stateId'] as String?)?.trim().isNotEmpty == true
        ? (city['stateId'] as String).trim()
        : (city['state'] as String? ?? '').trim();
    final districtId =
        (city['districtId'] as String?)?.trim().isNotEmpty == true
            ? (city['districtId'] as String).trim()
            : (city['district'] as String? ?? '').trim();
    final pincodes = (json['assignedPincodes'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => item['pincode'] as String? ?? '')
        .where((pincode) => pincode.isNotEmpty)
        .toSet()
        .toList(growable: false);
    return _AdminCatalogServiceArea(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cityId: json['cityId'] as String? ?? '',
      cityName: city['name'] as String? ?? '',
      stateId: stateId,
      stateName: city['state'] as String? ?? '',
      districtId: districtId,
      districtName: city['district'] as String? ?? '',
      pincodes: pincodes,
      isActive: json['isActive'] as bool? ?? true,
      cityIsActive: city['isActive'] as bool? ?? true,
    );
  }
}

class _ReorderSelection<T> {
  const _ReorderSelection({
    required this.parentId,
    required this.items,
  });

  final String parentId;
  final List<T> items;
}

class _AdminCategory {
  const _AdminCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.isActive,
    required this.featured,
    required this.popular,
    required this.sortOrder,
    required this.description,
    required this.iconUrl,
    required this.seoTitle,
    required this.seoDescription,
    required this.availabilityMode,
    required this.serviceAreaIds,
    required this.subcategories,
  });

  final String id;
  final String name;
  final String slug;
  final bool isActive;
  final bool featured;
  final bool popular;
  final int sortOrder;
  final String? description;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final String availabilityMode;
  final List<String> serviceAreaIds;
  final List<_AdminSubcategory> subcategories;

  int get serviceCount => subcategories.fold<int>(
      0, (sum, subcategory) => sum + subcategory.serviceCount);

  factory _AdminCategory.fromDetail(Map<String, dynamic> json,
      {_AdminCategory? fallback}) {
    final subcategories = (json['subcategories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_AdminSubcategory.fromJson)
        .toList(growable: false);
    return _AdminCategory(
      id: json['id'] as String? ?? fallback?.id ?? '',
      name: json['name'] as String? ?? fallback?.name ?? '',
      slug: json['slug'] as String? ?? fallback?.slug ?? '',
      isActive: json['isActive'] as bool? ?? fallback?.isActive ?? true,
      featured: json['featured'] as bool? ?? fallback?.featured ?? false,
      popular: json['popular'] as bool? ?? fallback?.popular ?? false,
      sortOrder:
          (json['sortOrder'] as num?)?.toInt() ?? fallback?.sortOrder ?? 0,
      description: json['description'] as String? ?? fallback?.description,
      iconUrl: json['iconUrl'] as String? ?? fallback?.iconUrl,
      seoTitle: json['seoTitle'] as String? ?? fallback?.seoTitle,
      seoDescription:
          json['seoDescription'] as String? ?? fallback?.seoDescription,
      availabilityMode: json['availabilityMode'] as String? ?? 'INHERITED',
      serviceAreaIds: _assignmentAreaIds(json['serviceAreaAssignments']),
      subcategories: subcategories,
    );
  }
}

class _AdminSubcategory {
  const _AdminSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    required this.basePrice,
    required this.isActive,
    required this.sortOrder,
    required this.description,
    required this.iconUrl,
    required this.seoTitle,
    required this.seoDescription,
    required this.rating,
    required this.reviewCount,
    required this.availabilityMode,
    required this.serviceAreaIds,
    required this.services,
  });

  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final double basePrice;
  final bool isActive;
  final int sortOrder;
  final String? description;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final double rating;
  final int reviewCount;
  final String availabilityMode;
  final List<String> serviceAreaIds;
  final List<_AdminService> services;

  int get serviceCount => services.length;

  factory _AdminSubcategory.fromJson(Map<String, dynamic> json) {
    final servicesJson = (json['catalogServices'] as List? ??
        json['services'] as List? ??
        const []);
    return _AdminSubcategory(
      id: json['id'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      basePrice: _toDouble(json['basePrice']),
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      rating: _toDouble(json['rating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      availabilityMode: json['availabilityMode'] as String? ?? 'INHERITED',
      serviceAreaIds: _assignmentAreaIds(json['serviceAreaAssignments']),
      services: servicesJson
          .whereType<Map<String, dynamic>>()
          .map(_AdminService.fromJson)
          .toList(growable: false),
    );
  }
}

class _AdminService {
  const _AdminService({
    required this.id,
    required this.categoryId,
    required this.subcategoryId,
    required this.name,
    required this.slug,
    required this.code,
    required this.startingPrice,
    required this.gstRate,
    required this.gstApplicable,
    required this.sacCode,
    required this.estimatedDurationMins,
    required this.isActive,
    required this.publicationStatus,
    required this.availabilityMode,
    required this.publishStartsAt,
    required this.publishEndsAt,
    required this.serviceAreaIds,
    required this.featured,
    required this.popular,
    required this.emergencyAvailable,
    required this.homeVisit,
    required this.requiresSiteVisit,
    required this.bookingEnabled,
    required this.maintenanceEnabled,
    required this.maintenanceIntervalsMonths,
    required this.maintenanceReminderHours,
    required this.priceType,
    required this.ctaLabel,
    required this.warrantyText,
    required this.requirements,
    required this.inclusions,
    required this.exclusions,
    required this.requiredSkills,
    required this.requiredTools,
    required this.requiredDocuments,
    required this.warrantyDays,
    required this.guaranteeEnabled,
    required this.guaranteeClaimWindowDays,
    required this.guaranteeIssueCategories,
    required this.guaranteeTerms,
    required this.guaranteeExclusions,
    required this.guaranteeResolutionTypes,
    required this.guaranteeRequiresPartnerReview,
    required this.guaranteeEvidenceRequired,
    required this.description,
    required this.shortDescription,
    required this.iconUrl,
    required this.seoTitle,
    required this.seoDescription,
    required this.seoKeywords,
    required this.cancellationPolicy,
    required this.rating,
    required this.reviewCount,
    required this.images,
    required this.pricingRules,
    required this.variants,
    required this.addons,
  });

  final String id;
  final String categoryId;
  final String subcategoryId;
  final String name;
  final String slug;
  final String? code;
  final double startingPrice;
  final double gstRate;
  final bool gstApplicable;
  final String sacCode;
  final int estimatedDurationMins;
  final bool isActive;
  final String publicationStatus;
  final String availabilityMode;
  final DateTime? publishStartsAt;
  final DateTime? publishEndsAt;
  final List<String> serviceAreaIds;
  final bool featured;
  final bool popular;
  final bool emergencyAvailable;
  final bool homeVisit;
  final bool requiresSiteVisit;
  final bool bookingEnabled;
  final bool maintenanceEnabled;
  final List<int> maintenanceIntervalsMonths;
  final int maintenanceReminderHours;
  final String priceType;
  final String ctaLabel;
  final String? warrantyText;
  final List<String> requirements;
  final List<String> inclusions;
  final List<String> exclusions;
  final List<String> requiredSkills;
  final List<String> requiredTools;
  final List<String> requiredDocuments;
  final int warrantyDays;
  final bool guaranteeEnabled;
  final int guaranteeClaimWindowDays;
  final List<String> guaranteeIssueCategories;
  final String? guaranteeTerms;
  final String? guaranteeExclusions;
  final List<String> guaranteeResolutionTypes;
  final bool guaranteeRequiresPartnerReview;
  final bool guaranteeEvidenceRequired;
  final String? description;
  final String? shortDescription;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
  final String? cancellationPolicy;
  final double rating;
  final int reviewCount;
  final List<_AdminServiceImage> images;
  final List<_AdminPricingRule> pricingRules;
  final List<_AdminServiceOption> variants;
  final List<_AdminServiceOption> addons;

  factory _AdminService.fromJson(Map<String, dynamic> json) {
    return _AdminService(
      id: json['id'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      subcategoryId: json['subcategoryId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      code: json['code'] as String?,
      startingPrice: _toDouble(json['startingPrice']),
      gstRate: json['gstRate'] == null ? 18 : _toDouble(json['gstRate']),
      gstApplicable: json['gstApplicable'] as bool? ?? true,
      sacCode: (json['sacCode'] as String?)?.trim().isNotEmpty == true
          ? json['sacCode'] as String
          : 'PENDING',
      estimatedDurationMins:
          (json['estimatedDurationMins'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      publicationStatus: json['publicationStatus'] as String? ?? 'PUBLISHED',
      availabilityMode: json['availabilityMode'] as String? ?? 'INHERITED',
      publishStartsAt:
          DateTime.tryParse(json['publishStartsAt'] as String? ?? '')
              ?.toLocal(),
      publishEndsAt:
          DateTime.tryParse(json['publishEndsAt'] as String? ?? '')?.toLocal(),
      serviceAreaIds: (json['serviceAreaAssignments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((assignment) => assignment['serviceAreaId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false),
      featured: json['featured'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      emergencyAvailable: json['emergencyAvailable'] as bool? ?? false,
      homeVisit: json['homeVisit'] as bool? ?? true,
      requiresSiteVisit: json['requiresSiteVisit'] as bool? ?? false,
      bookingEnabled: json['bookingEnabled'] as bool? ?? true,
      maintenanceEnabled: json['maintenanceEnabled'] as bool? ?? false,
      maintenanceIntervalsMonths:
          (json['maintenanceIntervalsMonths'] as List? ?? const <dynamic>[])
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(growable: false),
      maintenanceReminderHours:
          (json['maintenanceReminderHours'] as num?)?.toInt() ?? 24,
      priceType: json['priceType'] as String? ?? 'FROM',
      ctaLabel: json['ctaLabel'] as String? ?? 'Book service',
      warrantyText: json['warrantyText'] as String?,
      requirements: (json['requirements'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      inclusions: _serviceLinesFromJson(json['inclusions']),
      exclusions: _serviceLinesFromJson(json['exclusions']),
      requiredSkills: _serviceRequirementNames(json['requiredSkills']),
      requiredTools: _serviceRequirementNames(json['requiredTools']),
      requiredDocuments: _serviceRequirementNames(json['requiredDocuments']),
      warrantyDays: (json['warrantyDays'] as num?)?.toInt() ?? 0,
      guaranteeEnabled: json['guaranteeEnabled'] as bool? ?? false,
      guaranteeClaimWindowDays:
          (json['guaranteeClaimWindowDays'] as num?)?.toInt() ?? 0,
      guaranteeIssueCategories:
          (json['guaranteeIssueCategories'] as List? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      guaranteeTerms: json['guaranteeTerms'] as String?,
      guaranteeExclusions: json['guaranteeExclusions'] as String?,
      guaranteeResolutionTypes:
          (json['guaranteeResolutionTypes'] as List? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      guaranteeRequiresPartnerReview:
          json['guaranteeRequiresPartnerReview'] as bool? ?? false,
      guaranteeEvidenceRequired:
          json['guaranteeEvidenceRequired'] as bool? ?? false,
      description: json['description'] as String?,
      shortDescription: json['shortDescription'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      seoKeywords: json['seoKeywords'] as String?,
      cancellationPolicy: json['cancellationPolicy'] as String?,
      rating: _toDouble(json['rating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      images: (json['images'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminServiceImage.fromJson)
          .toList(growable: false),
      pricingRules: (json['pricingRules'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminPricingRule.fromJson)
          .toList(growable: false),
      variants: (json['variants'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _AdminServiceOption.fromJson(item, isVariant: true))
          .toList(growable: false),
      addons: (json['addons'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _AdminServiceOption.fromJson(item, isVariant: false))
          .toList(growable: false),
    );
  }
}

class _AdminServiceImage {
  const _AdminServiceImage({
    required this.id,
    required this.url,
    required this.altText,
    required this.sortOrder,
    required this.isPrimary,
  });

  final String id;
  final String url;
  final String altText;
  final int sortOrder;
  final bool isPrimary;

  factory _AdminServiceImage.fromJson(Map<String, dynamic> json) =>
      _AdminServiceImage(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        altText: json['altText'] as String? ?? '',
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        isPrimary: json['isPrimary'] as bool? ?? false,
      );
}

class _AdminServiceOption {
  const _AdminServiceOption({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.originalPrice,
    this.durationMins,
    this.isActive = true,
    this.availabilityMode = 'INHERITED',
    this.serviceAreaIds = const [],
  });

  final String id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final double? originalPrice;
  final int? durationMins;
  final bool isActive;
  final String availabilityMode;
  final List<String> serviceAreaIds;

  factory _AdminServiceOption.fromJson(
    Map<String, dynamic> json, {
    required bool isVariant,
  }) =>
      _AdminServiceOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: _toDouble(json['price']),
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        originalPrice: json['originalPrice'] == null
            ? null
            : _toDouble(json['originalPrice']),
        durationMins: (json['estimatedDurationMins'] as num?)?.toInt(),
        isActive: isVariant
            ? json['isAvailable'] as bool? ?? true
            : json['isActive'] as bool? ?? true,
        availabilityMode: isVariant
            ? json['availabilityMode'] as String? ?? 'INHERITED'
            : 'INHERITED',
        serviceAreaIds: isVariant
            ? _assignmentAreaIds(json['serviceAreaAssignments'])
            : const [],
      );
}

List<String> _assignmentAreaIds(dynamic value) => (value as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .map((assignment) => assignment['serviceAreaId'] as String? ?? '')
    .where((id) => id.isNotEmpty)
    .toList(growable: false);

class _AdminPricingRule {
  const _AdminPricingRule({
    required this.id,
    required this.type,
    required this.title,
    required this.price,
    required this.currency,
    required this.isActive,
    required this.priority,
  });

  final String id;
  final String type;
  final String title;
  final double price;
  final String currency;
  final bool isActive;
  final int priority;

  factory _AdminPricingRule.fromJson(Map<String, dynamic> json) {
    return _AdminPricingRule(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'BASE',
      title: json['title'] as String? ?? '',
      price: _toDouble(json['price']),
      currency: json['currency'] as String? ?? 'INR',
      isActive: json['isActive'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }
}

String _formatServiceOptions(List<_AdminServiceOption> options) => options
    .map((option) => [
          option.name,
          option.price.toStringAsFixed(2),
          option.durationMins?.toString() ?? '',
          option.isActive ? 'active' : 'inactive',
          option.description ?? '',
        ].join(' | '))
    .join('\n');

String? _validateServiceOptionLines(String? value) {
  final lines = (value ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length > 50) return 'Enter no more than 50 options';

  final names = <String>{};
  for (var index = 0; index < lines.length; index += 1) {
    final parts = lines[index].split('|').map((part) => part.trim()).toList();
    if (parts.length < 2 || parts[0].length < 2) {
      return 'Line ${index + 1}: use name | price | duration | status | description';
    }
    final price = double.tryParse(parts[1]);
    if (price == null || !price.isFinite || price < 0) {
      return 'Line ${index + 1}: enter a valid non-negative price';
    }
    if (parts.length > 2 &&
        parts[2].isNotEmpty &&
        (int.tryParse(parts[2]) == null || int.parse(parts[2]) <= 0)) {
      return 'Line ${index + 1}: duration must be a positive whole number';
    }
    if (parts.length > 3 &&
        parts[3].isNotEmpty &&
        !const {'active', 'inactive'}.contains(parts[3].toLowerCase())) {
      return 'Line ${index + 1}: status must be active or inactive';
    }
    if (!names.add(parts[0].toLowerCase())) {
      return 'Option names must be unique';
    }
  }
  return null;
}

String? _validateGuaranteeRemedies(String? value) {
  const allowed = {'REWORK', 'REVISIT', 'REFUND_REVIEW'};
  final invalid = _serviceLines(value ?? '')
      .map((item) => item.toUpperCase())
      .where((item) => !allowed.contains(item))
      .toList(growable: false);
  return invalid.isEmpty
      ? null
      : 'Unknown resolution type: ${invalid.first}. Use REWORK, REVISIT, or REFUND_REVIEW.';
}

Future<Map<String, dynamic>?> _showServiceGalleryImagePicker({
  required BuildContext context,
  required String serviceName,
  required Map<String, dynamic>? current,
  required Future<String> Function(Uint8List, String) uploadImage,
}) {
  String? selectedUrl;
  var altText = current?['altText']?.toString() ?? serviceName;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(
            current == null ? 'Add service image' : 'Replace service image'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current != null) ...[
                  Text('Current image',
                      style: Theme.of(dialogContext).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      current['url'] as String? ?? '',
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                          height: 100,
                          child:
                              Center(child: Icon(Icons.broken_image_outlined))),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  initialValue: altText,
                  decoration: const InputDecoration(labelText: 'Alt text'),
                  onChanged: (value) => altText = value,
                ),
                const SizedBox(height: 12),
                AdminImagePickerField(
                  label: 'Service gallery image',
                  value: selectedUrl,
                  onChanged: (value) =>
                      setDialogState(() => selectedUrl = value),
                  uploadImage: uploadImage,
                  recommendedWidth: 1200,
                  recommendedHeight: 840,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: selectedUrl == null
                ? null
                : () => Navigator.pop(dialogContext, {
                      'url': selectedUrl,
                      'altText':
                          altText.trim().isEmpty ? serviceName : altText.trim(),
                      'isPrimary': current?['isPrimary'] == true,
                    }),
            child: Text(current == null ? 'Add to gallery' : 'Use replacement'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildServiceOptionImageEditors({
  required BuildContext context,
  required TextEditingController controller,
  required Map<String, String?> selectedImageUrls,
  required String label,
  required StateSetter setState,
  required Future<String> Function(Uint8List, String) uploadImage,
}) {
  final names = controller.text
      .split('\n')
      .map((line) => line.split('|').first.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  if (names.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...names.map((name) {
          final key = name.toLowerCase();
          return Padding(
            key: ValueKey('$label:$key'),
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminImagePickerField(
              label: '$name image',
              value: selectedImageUrls[key],
              onChanged: (value) =>
                  setState(() => selectedImageUrls[key] = value),
              uploadImage: uploadImage,
              recommendedWidth: 800,
              recommendedHeight: 800,
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildServiceOptionAvailabilityEditors({
  required BuildContext context,
  required _CatalogSnapshot snapshot,
  required TextEditingController controller,
  required List<_AdminServiceOption> existingVariants,
  required Map<String, String> modes,
  required Map<String, Set<String>> areaIds,
  required StateSetter setState,
}) {
  final names = controller.text
      .split('\n')
      .map((line) => line.split('|').first.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) return const SizedBox.shrink();
  final activeDraftKeys = names
      .asMap()
      .entries
      .map((entry) => _variantAvailabilityKey(
            existingVariants,
            entry.key,
            entry.value,
            allNames: names,
          ))
      .where((key) => key.startsWith('draft:'))
      .toSet();
  modes.removeWhere(
      (key, _) => key.startsWith('draft:') && !activeDraftKeys.contains(key));
  areaIds.removeWhere(
      (key, _) => key.startsWith('draft:') && !activeDraftKeys.contains(key));

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Variant availability',
          style: Theme.of(context).textTheme.titleSmall),
      const Text(
          'Each variant inherits the service location rules by default. Existing variant rules stay with the variant when its name changes.'),
      ...names.asMap().entries.map((entry) {
        final name = entry.value;
        final key = _variantAvailabilityKey(
          existingVariants,
          entry.key,
          name,
          allNames: names,
        );
        final mode = modes[key] ??= 'INHERITED';
        final selectedIds = areaIds.putIfAbsent(key, () => <String>{});
        final visibleAreas = snapshot.serviceAreas
            .where((area) => area.isActive || selectedIds.contains(area.id))
            .toList(growable: false);
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  DropdownButtonFormField<String>(
                    key: ValueKey('variant-mode:$key:$mode'),
                    initialValue: mode,
                    decoration: const InputDecoration(
                      labelText: 'Availability',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'INHERITED', child: Text('Inherited')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => modes[key] = value);
                    },
                  ),
                  if (mode == 'CUSTOM') ...[
                    const SizedBox(height: 8),
                    for (final area in visibleAreas)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selectedIds.contains(area.id),
                        title: Text('${area.cityName} · ${area.name}'),
                        subtitle: Text(area.pincodes.join(', ')),
                        onChanged: (_) => setState(() {
                          if (!selectedIds.add(area.id)) {
                            selectedIds.remove(area.id);
                          }
                        }),
                      ),
                    if (selectedIds.isEmpty)
                      Text(
                        'Select at least one location for a custom variant.',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
    ],
  );
}

List<Map<String, dynamic>> _serviceOptionRows(
  String value,
  List<_AdminServiceOption> existing, {
  required bool isVariant,
  Map<String, String?> imageUrls = const {},
  Map<String, String> availabilityModes = const {},
  Map<String, Set<String>> serviceAreaIds = const {},
}) {
  final existingByName = {
    for (final option in existing) option.name.trim().toLowerCase(): option,
  };
  final lines = value
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final currentNames =
      lines.map((line) => line.split('|').first.trim()).toList(growable: false);
  return lines.asMap().entries.map((entry) {
    final parts = entry.value.split('|').map((part) => part.trim()).toList();
    final name = parts[0];
    final normalizedName = name.toLowerCase();
    final candidate = entry.key < existing.length ? existing[entry.key] : null;
    final candidateClaimedByAnotherRow = candidate != null &&
        candidate.name.trim().toLowerCase() != normalizedName &&
        currentNames.any(
          (rowName) =>
              rowName.trim().toLowerCase() ==
              candidate.name.trim().toLowerCase(),
        );
    final previous = existingByName[normalizedName] ??
        (candidateClaimedByAnotherRow ? null : candidate);
    final availabilityKey = isVariant
        ? _variantAvailabilityKey(
            existing,
            entry.key,
            name,
            allNames: currentNames,
          )
        : normalizedName;
    final duration = parts.length > 2 && parts[2].isNotEmpty
        ? int.tryParse(parts[2])
        : previous?.durationMins;
    final status = parts.length > 3 && parts[3].isNotEmpty
        ? parts[3].toLowerCase() == 'active'
        : previous?.isActive ?? true;
    final description = parts.length > 4 && parts[4].isNotEmpty
        ? parts.skip(4).join(' | ')
        : previous?.description;
    return <String, dynamic>{
      if (previous?.id.isNotEmpty == true) 'id': previous!.id,
      'name': name,
      'price': double.parse(parts[1]),
      'description': description,
      'imageUrl': imageUrls.containsKey(name.toLowerCase())
          ? imageUrls[name.toLowerCase()]
          : previous?.imageUrl,
      if (duration != null) 'estimatedDurationMins': duration,
      'sortOrder': entry.key,
      if (isVariant) ...{
        'originalPrice': previous?.originalPrice,
        'isAvailable': status,
        'availabilityMode': availabilityModes[availabilityKey] ??
            previous?.availabilityMode ??
            'INHERITED',
        'serviceAreaIds': (availabilityModes[availabilityKey] ??
                    previous?.availabilityMode ??
                    'INHERITED') ==
                'CUSTOM'
            ? serviceAreaIds[availabilityKey]?.toList() ??
                previous?.serviceAreaIds ??
                const <String>[]
            : const <String>[],
      } else
        'isActive': status,
    };
  }).toList(growable: false);
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

List<String> _serviceLines(String value) => value
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toList(growable: false);

List<Map<String, dynamic>> _serviceRequirementRows(String value) =>
    _serviceLines(value)
        .asMap()
        .entries
        .map(
          (entry) => {
            'name': entry.value,
            'slug': _slugify(entry.value),
            'isMandatory': true,
            'sortOrder': entry.key,
          },
        )
        .toList(growable: false);

List<String> _serviceLinesFromJson(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) => item is String ? item : null)
      .whereType<String>()
      .toList(growable: false);
}

List<String> _serviceRequirementNames(dynamic value) {
  if (value is! List) return const [];
  return value
      .map((item) {
        if (item is! Map) return null;
        final linked = item['skill'] ?? item['tool'];
        if (linked is Map && linked['name'] is String) {
          return linked['name'] as String;
        }
        return item['name'] is String ? item['name'] as String : null;
      })
      .whereType<String>()
      .toList(growable: false);
}

String _slugify(String value) {
  return value
      .replaceAll(RegExp(r'[^\w\s-]'), '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
