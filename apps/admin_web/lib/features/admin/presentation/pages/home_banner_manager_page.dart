import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/admin_image_picker_field.dart';
import '../widgets/admin_surface.dart';

class HomeBannerManagerPage extends ConsumerStatefulWidget {
  const HomeBannerManagerPage({super.key});

  @override
  ConsumerState<HomeBannerManagerPage> createState() =>
      _HomeBannerManagerPageState();
}

class _HomeBannerManagerPageState extends ConsumerState<HomeBannerManagerPage> {
  List<Map<String, dynamic>> _banners = const [];
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _services = const [];
  bool _destinationOptionsReady = false;
  bool _loading = true;
  String? _error;
  String _searchFilter = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final bannerResponse =
          await dio.get<dynamic>('/admin/catalog/home-banners');
      if (!mounted) return;
      setState(() => _banners = _asMapList(bannerResponse.data, 'banners'));
      try {
        final destinations = await dio.get<dynamic>(
          '/admin/catalog/home-banner-destinations',
        );
        if (!mounted) return;
        setState(() {
          _categories = _asMapList(destinations.data, 'categories');
          _services = _asMapList(destinations.data, 'services');
          _destinationOptionsReady = true;
        });
      } catch (_) {
        if (mounted) {
          setState(() {
            _destinationOptionsReady = false;
            _error =
                'Banners loaded, but catalog choices could not load. Retry to create or edit a banner.';
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load home banners.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _asMapList(dynamic payload, String key) {
    final values = payload is Map ? payload[key] : null;
    return values is List
        ? values
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
        : <Map<String, dynamic>>[];
  }

  String _bannerStatus(Map<String, dynamic> banner) {
    if (banner['isActive'] != true) return 'Disabled';
    final now = DateTime.now();
    final startsAt = DateTime.tryParse(banner['startsAt']?.toString() ?? '');
    final endsAt = DateTime.tryParse(banner['endsAt']?.toString() ?? '');
    if (startsAt != null && startsAt.isAfter(now)) return 'Scheduled';
    if (endsAt != null && !endsAt.isAfter(now)) return 'Expired';
    return 'Published';
  }

  String _destinationSummary(String type, String value) {
    switch (type) {
      case 'service':
        final service = _services.cast<Map<String, dynamic>?>().firstWhere(
              (item) => item?['slug'] == value,
              orElse: () => null,
            );
        return service == null
            ? 'Service page · unavailable service'
            : 'Service page · ${service['name']}';
      case 'category':
        if (value.isEmpty) return 'Category search · all categories';
        final category = _categories.cast<Map<String, dynamic>?>().firstWhere(
              (item) => item?['slug'] == value,
              orElse: () => null,
            );
        return category == null
            ? 'Category search · unavailable category'
            : 'Category search · ${category['name']}';
      case 'offer':
        return 'Offers page';
      case 'search':
        return value.isEmpty ? 'Search results' : 'Search results · $value';
      case 'custom_route':
        return 'Custom Customer app page';
      default:
        return 'Home page';
    }
  }

  String _bannerTitle(Map<String, dynamic> banner) {
    final value = banner['destinationValue']?.toString() ?? '';
    return _destinationSummary(
      banner['destinationType']?.toString() ?? '',
      value,
    );
  }

  List<Map<String, dynamic>> get _filteredBanners {
    final query = _searchFilter.trim().toLowerCase();
    return _banners.where((banner) {
      if (_statusFilter != 'all' &&
          _bannerStatus(banner).toLowerCase() != _statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return _bannerTitle(banner).toLowerCase().contains(query) ||
          _bannerStatus(banner).toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _saveBanner(Map<String, dynamic> values, {String? id}) async {
    final dio = ref.read(apiClientProvider).dio;
    final Response<dynamic> response;
    if (id == null) {
      response = await dio.post('/admin/catalog/home-banners', data: values);
    } else {
      response =
          await dio.patch('/admin/catalog/home-banners/$id', data: values);
    }
    final payload = response.data;
    final savedBanner = payload is Map ? payload['banner'] : null;
    if (mounted && savedBanner is Map) {
      final saved = savedBanner.cast<String, dynamic>();
      setState(() {
        _banners = [
          ..._banners.where((item) => item['id'] != saved['id']),
          saved,
        ]..sort((left, right) {
            final leftOrder = (left['sortOrder'] as num?)?.toInt() ?? 0;
            final rightOrder = (right['sortOrder'] as num?)?.toInt() ?? 0;
            return leftOrder.compareTo(rightOrder);
          });
      });
    }
    await _load();
  }

  String _saveErrorMessage(Object error, {String action = 'saving'}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message is String &&
            message.trim().isNotEmpty &&
            message != 'Validation failed') {
          return message.trim();
        }
        final issues = data['issues'];
        if (issues is List) {
          for (final issue in issues.whereType<Map>()) {
            final message = issue['message'];
            if (message is String && message.trim().isNotEmpty) {
              return message.trim();
            }
          }
        }
      }
      if (error.response == null) {
        return 'Network error while $action. Check your connection and retry.';
      }
    }
    return 'Could not complete banner $action. Check the details and retry.';
  }

  Future<String> _uploadBannerImage(Uint8List bytes, String fileName) async {
    try {
      final response =
          await ref.read(apiClientProvider).dio.post<Map<String, dynamic>>(
                '/media/catalog',
                data: FormData.fromMap({
                  'file': MultipartFile.fromBytes(bytes, filename: fileName),
                }),
              );
      final url = response.data?['url'];
      if (url is! String || !url.startsWith('https://')) {
        throw StateError('The image upload returned an invalid URL.');
      }
      return url;
    } on DioException catch (error) {
      throw StateError(
        _saveErrorMessage(error, action: 'uploading the image'),
      );
    }
  }

  Future<void> _showEditor([Map<String, dynamic>? banner]) async {
    if (!_destinationOptionsReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refresh the banner list to load destination choices.'),
        ),
      );
      return;
    }
    String? imageUrl = banner?['imageUrl']?.toString();
    var destinationValue = banner?['destinationValue']?.toString() ?? '';
    final destinationController = TextEditingController(
      text: destinationValue,
    );
    final orderController = TextEditingController(
      text: (banner?['sortOrder'] ?? _banners.length).toString(),
    );
    const supportedDestinationTypes = {
      'service',
      'category',
      'offer',
      'search',
      'custom_route',
    };
    final storedDestinationType = banner?['destinationType']?.toString();
    var destinationType = supportedDestinationTypes.contains(
      storedDestinationType,
    )
        ? storedDestinationType!
        : 'service';
    var isActive = banner?['isActive'] as bool? ?? true;
    DateTime? startsAt =
        DateTime.tryParse(banner?['startsAt']?.toString() ?? '')?.toLocal();
    DateTime? endsAt =
        DateTime.tryParse(banner?['endsAt']?.toString() ?? '')?.toLocal();
    String? error;
    var saving = false;
    var imageUploadPending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _BannerDialogControllerOwner(
        controllers: [
          destinationController,
          orderController,
        ],
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title:
                Text(banner == null ? 'Add home banner' : 'Edit home banner'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A · Banner image',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    AdminImagePickerField(
                      label: 'Banner image',
                      value: imageUrl,
                      onChanged: (value) =>
                          setDialogState(() => imageUrl = value),
                      onPendingUploadChanged: (pending) => setDialogState(
                        () => imageUploadPending = pending,
                      ),
                      uploadImage: _uploadBannerImage,
                      recommendedWidth: 1200,
                      recommendedHeight: 630,
                      showCustomerPreview: true,
                    ),
                    const SizedBox(height: 12),
                    Text('B · Tap destination',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: destinationType,
                      decoration:
                          const InputDecoration(labelText: 'Tap destination'),
                      items: const [
                        DropdownMenuItem(
                            value: 'service', child: Text('Service page')),
                        DropdownMenuItem(
                            value: 'category', child: Text('Category search')),
                        DropdownMenuItem(value: 'offer', child: Text('Offers')),
                        DropdownMenuItem(
                            value: 'search', child: Text('Search results')),
                        DropdownMenuItem(
                            value: 'custom_route',
                            child: Text('Custom app route')),
                      ],
                      onChanged: (value) => setDialogState(() {
                        final nextType = value ?? 'service';
                        if (nextType != destinationType) {
                          destinationController.clear();
                          destinationValue = '';
                          error = null;
                        }
                        destinationType = nextType;
                      }),
                    ),
                    const SizedBox(height: 12),
                    if (destinationType == 'service')
                      _DestinationAutocomplete(
                        key: const ValueKey('service-destination'),
                        label: 'Choose a service',
                        options: _services,
                        selectedSlug: destinationValue,
                        labelFor: (service) {
                          final category = service['category'];
                          final categoryName = category is Map
                              ? category['name']?.toString()
                              : null;
                          final name = service['name']?.toString() ?? 'Service';
                          return categoryName == null || categoryName.isEmpty
                              ? name
                              : '$name · $categoryName';
                        },
                        slugFor: (service) => service['slug']?.toString() ?? '',
                        onSelected: (slug) => setDialogState(() {
                          destinationValue = slug;
                          error = null;
                        }),
                        onQueryChanged: () => setDialogState(() {
                          destinationValue = '';
                          error = null;
                        }),
                      )
                    else if (destinationType == 'category') ...[
                      _DestinationAutocomplete(
                        key: const ValueKey('category-destination'),
                        label: 'Choose a category (optional)',
                        options: [
                          {
                            'id': 'all-categories',
                            'name': 'All categories',
                            'slug': ''
                          },
                          ..._categories,
                        ],
                        selectedSlug: destinationValue,
                        labelFor: (category) =>
                            category['name']?.toString() ?? 'Category',
                        slugFor: (category) =>
                            category['slug']?.toString() ?? '',
                        onSelected: (slug) => setDialogState(() {
                          destinationValue = slug;
                          error = null;
                        }),
                        onQueryChanged: () => setDialogState(() {
                          destinationValue = '';
                          error = null;
                        }),
                      ),
                    ] else if (destinationType == 'offer')
                      Text(
                        'This banner opens the Offers page.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      TextField(
                        controller: destinationController,
                        onChanged: (value) => setDialogState(() {
                          destinationValue = value.trim();
                          error = null;
                        }),
                        decoration: InputDecoration(
                          labelText: switch (destinationType) {
                            'search' => 'Search query',
                            _ =>
                              'Internal route (for example /search?q=cleaning)',
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text('C · Display settings',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Display order'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Visible on Customer Home'),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                    ),
                    Text(
                      'Scheduled banners appear only between their start and end dates.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await _pickDate(context, startsAt);
                              if (date != null) {
                                setDialogState(() => startsAt = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(startsAt == null
                                ? 'Starts anytime'
                                : _formatDate(startsAt!)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final date = await _pickDate(context, endsAt);
                              if (date != null) {
                                setDialogState(() => endsAt = date);
                              }
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(endsAt == null
                                ? 'No end date'
                                : _formatDate(endsAt!)),
                          ),
                        ),
                      ],
                    ),
                    if (startsAt != null || endsAt != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setDialogState(() {
                            startsAt = null;
                            endsAt = null;
                          }),
                          child: const Text('Clear dates'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap action: ${_destinationSummary(destinationType, destinationValue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving || imageUploadPending
                    ? null
                    : () async {
                        final selectedImageUrl = imageUrl?.trim() ?? '';
                        final selectedDestinationValue =
                            destinationValue.trim();
                        final sortOrder =
                            int.tryParse(orderController.text.trim());
                        if (!selectedImageUrl.startsWith('https://')) {
                          setDialogState(() => error =
                              'Upload a JPG or PNG banner image before saving.');
                          return;
                        }
                        if ((destinationType == 'service' ||
                                destinationType == 'search' ||
                                destinationType == 'custom_route') &&
                            selectedDestinationValue.isEmpty) {
                          setDialogState(
                              () => error = switch (destinationType) {
                                    'service' => 'Enter a service slug.',
                                    'search' => 'Enter a search query.',
                                    _ => 'Enter an internal app route.',
                                  });
                          return;
                        }
                        if (sortOrder == null ||
                            sortOrder < 0 ||
                            sortOrder > 10000) {
                          setDialogState(() => error =
                              'Display order must be a whole number from 0 to 10000.');
                          return;
                        }
                        if (startsAt != null &&
                            endsAt != null &&
                            startsAt!.isAfter(endsAt!)) {
                          setDialogState(() => error =
                              'Start date must be on or before end date.');
                          return;
                        }
                        if (destinationType == 'service' &&
                            !_services.any((service) =>
                                service['slug'] == selectedDestinationValue)) {
                          setDialogState(() => error =
                              'Choose a service that is still available in the catalog.');
                          return;
                        }
                        if (destinationType == 'category' &&
                            selectedDestinationValue.isNotEmpty &&
                            !_categories.any((category) =>
                                category['slug'] == selectedDestinationValue)) {
                          setDialogState(() => error =
                              'Choose a category that is still available in the catalog.');
                          return;
                        }
                        if (destinationType == 'custom_route') {
                          final uri = Uri.tryParse(selectedDestinationValue);
                          if (uri == null ||
                              uri.hasAuthority ||
                              uri.scheme.isNotEmpty ||
                              !uri.path.startsWith('/') ||
                              uri.path.startsWith('//') ||
                              !_isSupportedCustomerRoute(uri.path)) {
                            setDialogState(() => error =
                                'Choose a supported Customer app route.');
                            return;
                          }
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await _saveBanner(
                            {
                              'imageUrl': selectedImageUrl,
                              'isActive': isActive,
                              'sortOrder': sortOrder,
                              'destinationType': destinationType,
                              'destinationValue': destinationType == 'offer'
                                  ? ''
                                  : selectedDestinationValue,
                              'startsAt': startsAt?.toUtc().toIso8601String(),
                              'endsAt': endsAt == null
                                  ? null
                                  : DateTime(
                                      endsAt!.year,
                                      endsAt!.month,
                                      endsAt!.day,
                                      23,
                                      59,
                                      59,
                                      999,
                                    ).toUtc().toIso8601String(),
                            },
                            id: banner?['id']?.toString(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Banner saved successfully.'),
                              ),
                            );
                          }
                        } catch (saveError) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              error = _saveErrorMessage(saveError);
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save banner'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSupportedCustomerRoute(String path) {
    const allowed = {
      '/app',
      '/service',
      '/professional',
      '/checkout',
      '/tracking',
      '/chat',
      '/search',
      '/notifications',
      '/referral',
      '/support',
      '/bookings',
      '/booking',
      '/invoice',
      '/arrival-otp',
      '/completion-otp',
      '/booking-rating',
      '/profile',
      '/cart',
      '/addresses',
      '/wallet',
      '/offers',
      '/favorites',
      '/maintenance-plans',
      '/settings',
      '/map-picker',
    };
    return allowed.any((route) => path == route || path.startsWith('$route/'));
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) =>
      showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

  String _formatDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _deleteBanner(Map<String, dynamic> banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete home banner?'),
        content: const Text(
            'This banner will no longer appear in the customer app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).dio.delete(
            '/admin/catalog/home-banners/${banner['id']}',
          );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not delete this banner.');
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> banner, bool active) async {
    try {
      await ref.read(apiClientProvider).dio.patch(
        '/admin/catalog/home-banners/${banner['id']}',
        data: {'isActive': active},
      );
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update banner status.');
    }
  }

  Future<void> _reorderBanners(int oldIndex, int newIndex) async {
    if (_statusFilter != 'all' || _searchFilter.trim().isNotEmpty) return;
    if (oldIndex == 0 || newIndex == 0) return;
    final from = oldIndex - 1;
    final to = newIndex - 1;
    if (from < 0 ||
        to < 0 ||
        from >= _banners.length ||
        to >= _banners.length) {
      return;
    }
    final reordered = [..._banners];
    final moved = reordered.removeAt(from);
    reordered.insert(to, moved);
    final normalized = [
      for (var index = 0; index < reordered.length; index++)
        {...reordered[index], 'sortOrder': index},
    ];
    setState(() => _banners = normalized);
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.post(
        '/admin/catalog/home-banners/reorder',
        data: {'ids': normalized.map((banner) => banner['id']).toList()},
      );
      await _load();
    } catch (error) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_saveErrorMessage(error))),
        );
      }
    }
  }

  Future<void> _duplicateBanner(Map<String, dynamic> banner) async {
    try {
      final nextOrder = _banners.fold<int>(-1, (maxOrder, item) {
            final order = (item['sortOrder'] as num?)?.toInt() ?? 0;
            return order > maxOrder ? order : maxOrder;
          }) +
          1;
      await _saveBanner({
        'imageUrl': banner['imageUrl'],
        'isActive': false,
        'sortOrder': nextOrder,
        'destinationType': banner['destinationType'],
        'destinationValue': banner['destinationValue'],
        'startsAt': banner['startsAt'],
        'endsAt': banner['endsAt'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banner duplicated as inactive.')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not duplicate this banner.');
    }
  }

  Future<void> _previewCustomerBanner(Map<String, dynamic> banner) async {
    final imageUrl = banner['imageUrl']?.toString() ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text('Preview customer view',
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Original preview',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 280),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox(
                                height: 120,
                                child: Center(
                                  child: Text('Image preview unavailable.'),
                                ),
                              )),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Customer preview',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 328),
                      child: AspectRatio(
                        aspectRatio: 328 / 172,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: Color(0xFFECE6DB),
                              child: Center(
                                child: Text('Image preview unavailable.'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('328 × 172 dp · BoxFit.cover · 20 dp corners',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Tap destination: ${_destinationSummary(
                      banner['destinationType']?.toString() ?? '',
                      banner['destinationValue']?.toString() ?? '',
                    )}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Home banners',
      actions: [
        IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded)),
        const SizedBox(width: 8),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: ReorderableListView(
          padding: const EdgeInsets.all(24),
          buildDefaultDragHandles: false,
          onReorderItem: _reorderBanners,
          children: [
            KeyedSubtree(
              key: const ValueKey('home-banner-manager-header'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AdminSectionHeader(
                    title: 'Customer home hero',
                    subtitle:
                        'Choose an image, where it opens, when it appears, and its position on Customer Home.',
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _showEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add banner'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _searchFilter = value),
                          decoration: const InputDecoration(
                            labelText: 'Search banners',
                            hintText: 'Search by destination or service',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 190,
                        child: DropdownButtonFormField<String>(
                          initialValue: _statusFilter,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All statuses')),
                            DropdownMenuItem(
                                value: 'published', child: Text('Published')),
                            DropdownMenuItem(
                                value: 'scheduled', child: Text('Scheduled')),
                            DropdownMenuItem(
                                value: 'expired', child: Text('Expired')),
                            DropdownMenuItem(
                                value: 'disabled', child: Text('Disabled')),
                          ],
                          onChanged: (value) =>
                              setState(() => _statusFilter = value ?? 'all'),
                        ),
                      ),
                      Text(
                          '${_filteredBanners.length} banner${_filteredBanners.length == 1 ? '' : 's'}'),
                    ],
                  ),
                  if (_error != null && _banners.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 12),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null && _banners.isEmpty)
                    AdminSurfacePanel(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_banners.isEmpty)
                    const AdminSurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                            'No banners yet. Add one to show an image-only hero on the customer home screen.'),
                      ),
                    )
                  else if (_filteredBanners.isEmpty)
                    const AdminSurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No banners match these filters.'),
                      ),
                    )
                  else ...[
                    if (_statusFilter != 'all' ||
                        _searchFilter.trim().isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child:
                            Text('Clear filters to drag and reorder banners.'),
                      ),
                  ],
                ],
              ),
            ),
            if (!_loading && _banners.isNotEmpty)
              ..._filteredBanners.asMap().entries.map((entry) {
                return KeyedSubtree(
                  key: ValueKey(entry.value['id']),
                  child: _bannerCard(
                    entry.value,
                    reorderIndex: entry.key + 1,
                    reorderEnabled:
                        _statusFilter == 'all' && _searchFilter.trim().isEmpty,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _bannerCard(
    Map<String, dynamic> banner, {
    required int reorderIndex,
    required bool reorderEnabled,
  }) {
    final active = banner['isActive'] == true;
    final status = _bannerStatus(banner);
    final cs = Theme.of(context).colorScheme;
    final startsAt =
        DateTime.tryParse(banner['startsAt']?.toString() ?? '')?.toLocal();
    final endsAt =
        DateTime.tryParse(banner['endsAt']?.toString() ?? '')?.toLocal();
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        banner['imageUrl']?.toString() ?? '',
        width: 180,
        height: 180 * (172 / 328),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 180,
          height: 180 * (172 / 328),
          color: cs.surfaceContainerHighest,
          child: const Center(
            child: Text(
              'Image preview unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_bannerTitle(banner),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            visualDensity: VisualDensity.compact,
            label: Text(status),
            backgroundColor: status == 'Published'
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(
            'Tap destination: ${_destinationSummary(
              banner['destinationType']?.toString() ?? '',
              banner['destinationValue']?.toString() ?? '',
            )}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          'Display order ${banner['sortOrder'] ?? 0} · ${startsAt == null ? 'Starts anytime' : _formatDate(startsAt)} → ${endsAt == null ? 'No end date' : _formatDate(endsAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (banner['updatedAt'] != null) ...[
          const SizedBox(height: 4),
          Text(
              'Updated ${_formatDate(DateTime.tryParse(banner['updatedAt'].toString())?.toLocal() ?? DateTime.now())}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
    final controls = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: active ? 'Disable banner' : 'Publish banner',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(active ? 'Published' : 'Disabled'),
              Switch.adaptive(
                value: active,
                onChanged: (value) => _toggleActive(banner, value),
              ),
            ],
          ),
        ),
        if (reorderEnabled)
          ReorderableDragStartListener(
            index: reorderIndex,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded),
            ),
          ),
        IconButton(
          tooltip: 'Edit',
          onPressed: () => _showEditor(banner),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Preview customer view',
          onPressed: () => _previewCustomerBanner(banner),
          icon: const Icon(Icons.preview_outlined),
        ),
        IconButton(
          tooltip: 'Duplicate',
          onPressed: () => _duplicateBanner(banner),
          icon: const Icon(Icons.copy_all_outlined),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () => _deleteBanner(banner),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminSurfacePanel(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                final imageWidth = constraints.maxWidth < 360 ? 104.0 : 132.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: imageWidth,
                          height: imageWidth * (172 / 328),
                          child: image,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: information),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: controls),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  image,
                  const SizedBox(width: 16),
                  Expanded(child: information),
                  controls,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DestinationAutocomplete extends StatelessWidget {
  const _DestinationAutocomplete({
    required this.label,
    required this.options,
    required this.selectedSlug,
    required this.labelFor,
    required this.slugFor,
    required this.onSelected,
    required this.onQueryChanged,
    super.key,
  });

  final String label;
  final List<Map<String, dynamic>> options;
  final String selectedSlug;
  final String Function(Map<String, dynamic>) labelFor;
  final String Function(Map<String, dynamic>) slugFor;
  final ValueChanged<String> onSelected;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((item) => slugFor(item) == selectedSlug);
    final initialText = selected.isEmpty
        ? (selectedSlug.isEmpty
            ? ''
            : 'Previously selected option is unavailable')
        : labelFor(selected.first);
    return Autocomplete<Map<String, dynamic>>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: labelFor,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return options;
        return options.where((item) =>
            labelFor(item).toLowerCase().contains(query) ||
            slugFor(item).toLowerCase().contains(query));
      },
      onSelected: (item) => onSelected(slugFor(item)),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) =>
          TextFormField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onQueryChanged(),
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Type to find an option from the active catalog.',
          suffixIcon: const Icon(Icons.search_rounded),
        ),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final item = options.elementAt(index);
                return ListTile(
                  title: Text(labelFor(item)),
                  onTap: () => onSelected(item),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns the editor controllers for the lifetime of the dialog route. The
/// widget is removed after the dialog's exit transition completes.
class _BannerDialogControllerOwner extends StatefulWidget {
  const _BannerDialogControllerOwner({
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_BannerDialogControllerOwner> createState() =>
      _BannerDialogControllerOwnerState();
}

class _BannerDialogControllerOwnerState
    extends State<_BannerDialogControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
