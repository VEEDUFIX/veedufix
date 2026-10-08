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
  bool _loading = true;
  String? _error;

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
      final response = await ref.read(apiClientProvider).dio.get<dynamic>(
            '/admin/catalog/home-banners',
          );
      final payload = response.data;
      final values = payload is Map ? payload['banners'] : null;
      if (!mounted) return;
      setState(() {
        _banners = values is List
            ? values
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .toList()
            : const [];
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load home banners.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBanner(Map<String, dynamic> values, {String? id}) async {
    final dio = ref.read(apiClientProvider).dio;
    if (id == null) {
      await dio.post('/admin/catalog/home-banners', data: values);
    } else {
      await dio.patch('/admin/catalog/home-banners/$id', data: values);
    }
    await _load();
  }

  Future<String> _uploadBannerImage(Uint8List bytes, String fileName) async {
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
  }

  Future<void> _showEditor([Map<String, dynamic>? banner]) async {
    String? imageUrl = banner?['imageUrl']?.toString();
    final destinationController = TextEditingController(
      text: banner?['destinationValue']?.toString() ?? '',
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
                    AdminImagePickerField(
                      label: 'Banner image',
                      value: imageUrl,
                      onChanged: (value) =>
                          setDialogState(() => imageUrl = value),
                      uploadImage: _uploadBannerImage,
                      recommendedWidth: 1200,
                      recommendedHeight: 630,
                      showCustomerPreview: true,
                    ),
                    const SizedBox(height: 12),
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
                      onChanged: (value) => setDialogState(
                        () => destinationType = value ?? 'service',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: destinationController,
                      decoration: InputDecoration(
                        labelText: switch (destinationType) {
                          'service' => 'Service slug',
                          'category' => 'Category slug',
                          'offer' => 'Optional offer identifier',
                          'search' => 'Search query',
                          _ =>
                            'Internal route (for example /search?q=cleaning)',
                        },
                        helperText: destinationType == 'offer'
                            ? 'Leave empty to open the offers page.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: orderController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Display order'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
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
                onPressed: saving
                    ? null
                    : () async {
                        final selectedImageUrl = imageUrl?.trim() ?? '';
                        final destinationValue =
                            destinationController.text.trim();
                        final sortOrder =
                            int.tryParse(orderController.text.trim());
                        if (!selectedImageUrl.startsWith('https://') ||
                            (destinationValue.isEmpty &&
                                destinationType != 'offer') ||
                            sortOrder == null ||
                            sortOrder < 0 ||
                            (startsAt != null &&
                                endsAt != null &&
                                startsAt!.isAfter(endsAt!))) {
                          setDialogState(() => error =
                              'Choose an image and check the destination, order, and dates.');
                          return;
                        }
                        if (destinationType == 'custom_route') {
                          final uri = Uri.tryParse(destinationValue);
                          if (uri == null ||
                              uri.hasAuthority ||
                              uri.scheme.isNotEmpty ||
                              !uri.path.startsWith('/') ||
                              uri.path.startsWith('//')) {
                            setDialogState(() => error =
                                'Custom destinations must be internal app routes.');
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
                              'destinationValue': destinationValue.isEmpty &&
                                      destinationType == 'offer'
                                  ? 'offers'
                                  : destinationValue,
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
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              error = 'Could not save this banner. Try again.';
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
                                  child: Icon(Icons.broken_image_outlined)))),
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
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFFECE6DB)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('328 × 172 dp · BoxFit.cover · 20 dp corners',
                      style: Theme.of(context).textTheme.bodySmall),
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const AdminSectionHeader(
              title: 'Customer home hero',
              subtitle:
                  'Control the image, visibility, schedule, order, and tap destination for each banner.',
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
            if (_error != null && _banners.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
            else
              ..._banners.map(_bannerCard),
          ],
        ),
      ),
    );
  }

  Widget _bannerCard(Map<String, dynamic> banner) {
    final active = banner['isActive'] == true;
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
          child: const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Home banner · order ${banner['sortOrder'] ?? 0}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(active ? 'Active' : 'Inactive',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: active ? cs.primary : cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
            'Destination: ${banner['destinationType']} · ${banner['destinationValue'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          '${startsAt == null ? 'Always' : _formatDate(startsAt)} → ${endsAt == null ? 'No end date' : _formatDate(endsAt)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final controls = Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Switch.adaptive(
          value: active,
          onChanged: (value) => _toggleActive(banner, value),
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
          tooltip: 'Delete / archive',
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
