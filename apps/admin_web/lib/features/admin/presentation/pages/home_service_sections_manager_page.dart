import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../widgets/admin_surface.dart';

class HomeServiceSectionsManagerPage extends ConsumerStatefulWidget {
  const HomeServiceSectionsManagerPage({super.key});

  @override
  ConsumerState<HomeServiceSectionsManagerPage> createState() =>
      _HomeServiceSectionsManagerPageState();
}

class _HomeServiceSectionsManagerPageState
    extends ConsumerState<HomeServiceSectionsManagerPage> {
  List<Map<String, dynamic>> _sections = const [];
  List<Map<String, dynamic>> _services = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final dio = ref.read(apiClientProvider).dio;
      final responses = await Future.wait([
        dio.get<dynamic>('/admin/catalog/home-sections'),
        dio.get<dynamic>('/admin/catalog/home-section-services'),
      ]);
      final sectionData = responses[0].data;
      final serviceData = responses[1].data;
      if (!mounted) return;
      setState(() {
        _sections = _asMapList(sectionData, 'sections');
        _services = _asMapList(serviceData, 'services');
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load Home sections.');
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

  Future<void> _save(Map<String, dynamic> body, {String? id}) async {
    final dio = ref.read(apiClientProvider).dio;
    if (id == null) {
      await dio.post('/admin/catalog/home-sections', data: body);
    } else {
      await dio.patch('/admin/catalog/home-sections/$id', data: body);
    }
    await _load();
  }

  Future<void> _delete(Map<String, dynamic> section) async {
    final id = section['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Home section?'),
            content: Text(
                '“${section['title']}” will be removed from the app Home screen.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || id.isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .delete('/admin/catalog/home-sections/$id');
      await _load();
    } catch (_) {
      if (mounted) _showMessage('Could not delete the Home section.');
    }
  }

  Future<void> _edit([Map<String, dynamic>? section]) async {
    if (_services.isEmpty) {
      _showMessage('There are no active catalog services to add yet.');
      return;
    }
    final title =
        TextEditingController(text: section?['title']?.toString() ?? '');
    final subtitle =
        TextEditingController(text: section?['subtitle']?.toString() ?? '');
    final destination = TextEditingController(
      text: section?['seeAllDestination']?.toString() ?? '/search',
    );
    final order = TextEditingController(
      text: (section?['sortOrder'] ?? _sections.length).toString(),
    );
    final rawItems = section?['items'];
    final selected = <String>[
      if (rawItems is List)
        for (final item in rawItems.whereType<Map>())
          if (item['service'] is Map)
            (item['service'] as Map)['id']?.toString() ?? '',
    ]..removeWhere((id) => id.isEmpty);
    final activeServiceIds = _services
        .map((service) => service['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    var active = section?['isActive'] as bool? ?? true;
    String? error;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _SectionDialogControllerOwner(
        controllers: [title, subtitle, destination, order],
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
                section == null ? 'Create Home section' : 'Edit Home section'),
            content: SizedBox(
              width: 620,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: title,
                      maxLength: 120,
                      decoration:
                          const InputDecoration(labelText: 'Section title'),
                    ),
                    TextField(
                      controller: subtitle,
                      maxLength: 240,
                      decoration: const InputDecoration(
                          labelText: 'Subtitle (optional)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: order,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Display order'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: destination,
                            decoration: const InputDecoration(
                              labelText: 'See all route',
                              hintText: '/search?q=cleaning',
                            ),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show on customer Home'),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                    const Divider(height: 24),
                    Text('Services in this section',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Select services and use the arrows to set their display order.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (selected.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Choose at least one service.'),
                      ),
                    for (var index = 0; index < selected.length; index++)
                      _selectedServiceTile(
                        context,
                        selected[index],
                        index,
                        selected.length,
                        setDialogState,
                        selected,
                      ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title:
                          Text('Add from ${_services.length} active services'),
                      children: [
                        if (_services.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('No active services are available.'),
                          )
                        else
                          SizedBox(
                            height: 260,
                            child: ListView.builder(
                              itemCount: _services.length,
                              itemBuilder: (context, index) {
                                final service = _services[index];
                                final id = service['id']?.toString() ?? '';
                                final isSelected = selected.contains(id);
                                final category = service['category'] is Map
                                    ? (service['category'] as Map)['name']
                                        ?.toString()
                                    : null;
                                return CheckboxListTile(
                                  dense: true,
                                  value: isSelected,
                                  title: Text(
                                      service['name']?.toString() ?? 'Service'),
                                  subtitle:
                                      category == null ? null : Text(category),
                                  onChanged: (value) => setDialogState(() {
                                    if (value == true) {
                                      if (selected.length >= 30) {
                                        error =
                                            'A section can contain at most 30 services.';
                                        return;
                                      }
                                      if (!selected.contains(id)) {
                                        selected.add(id);
                                      }
                                      error = null;
                                    } else {
                                      selected.remove(id);
                                      error = null;
                                    }
                                  }),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final parsedOrder = int.tryParse(order.text.trim());
                        final route = Uri.tryParse(destination.text.trim());
                        if (title.text.trim().length < 2) {
                          setDialogState(() => error =
                              'Enter a title with at least 2 characters.');
                          return;
                        }
                        final servicesToSave = selected
                            .where(activeServiceIds.contains)
                            .toList(growable: false);
                        if (servicesToSave.isEmpty ||
                            servicesToSave.length > 30) {
                          setDialogState(() => error =
                              'Choose between 1 and 30 active services.');
                          return;
                        }
                        if (parsedOrder == null || parsedOrder < 0) {
                          setDialogState(() =>
                              error = 'Display order must be zero or higher.');
                          return;
                        }
                        if (route == null ||
                            route.hasAuthority ||
                            route.scheme.isNotEmpty ||
                            !route.path.startsWith('/') ||
                            route.path.startsWith('//')) {
                          setDialogState(() => error =
                              'Use an internal route beginning with /.');
                          return;
                        }
                        setDialogState(() {
                          error = null;
                          saving = true;
                        });
                        try {
                          await _save({
                            'title': title.text.trim(),
                            'subtitle': subtitle.text.trim().isEmpty
                                ? null
                                : subtitle.text.trim(),
                            'sortOrder': parsedOrder,
                            'isActive': active,
                            'seeAllDestination': route.toString(),
                            'serviceIds': servicesToSave,
                          }, id: section?['id']?.toString());
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              error =
                                  'Could not save. Check your values and try again.';
                            });
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving…' : 'Save section'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedServiceTile(
    BuildContext context,
    String id,
    int index,
    int count,
    StateSetter setDialogState,
    List<String> selected,
  ) {
    Map<String, dynamic>? service;
    for (final candidate in _services) {
      if (candidate['id']?.toString() == id) {
        service = candidate;
        break;
      }
    }
    final unavailable = service == null;
    final category = service?['category'];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
      title: Text(service?['name']?.toString() ?? id),
      subtitle: unavailable
          ? const Text('Inactive or unavailable · remove this service')
          : category is Map
              ? Text(category['name']?.toString() ?? '')
              : null,
      trailing: SizedBox(
        width: 132,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Move up',
              visualDensity: VisualDensity.compact,
              onPressed: index == 0
                  ? null
                  : () => setDialogState(() {
                        final item = selected.removeAt(index);
                        selected.insert(index - 1, item);
                      }),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              visualDensity: VisualDensity.compact,
              onPressed: index >= count - 1
                  ? null
                  : () => setDialogState(() {
                        final item = selected.removeAt(index);
                        selected.insert(index + 1, item);
                      }),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Remove service',
              visualDensity: VisualDensity.compact,
              onPressed: () => setDialogState(() => selected.removeAt(index)),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Home service sections',
      actions: [
        IconButton(
            onPressed: _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded)),
        const SizedBox(width: 8),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const AdminSectionHeader(
              title: 'Customer Home sections',
              subtitle:
                  'Choose which service collections appear, in what order, and where “See all” leads.',
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading ? null : () => _edit(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add section'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (_error != null)
              AdminSurfacePanel(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(_error!),
                  trailing:
                      TextButton(onPressed: _load, child: const Text('Retry')),
                ),
              )
            else if (_sections.isEmpty)
              const AdminSurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'No custom sections yet. Add one to control service collections on the customer Home screen.'),
                ),
              )
            else
              for (final section in _sections)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdminSurfacePanel(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      leading: CircleAvatar(
                          child: Text('${section['sortOrder'] ?? 0}')),
                      title: Text(section['title']?.toString() ?? 'Section',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        '${(section['items'] is List ? (section['items'] as List).length : 0)} services · ${section['isActive'] == true ? 'Visible' : 'Hidden'} · ${section['seeAllDestination'] ?? '/search'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              tooltip: 'Edit',
                              onPressed: () => _edit(section),
                              icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _delete(section),
                              icon: const Icon(Icons.delete_outline_rounded)),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SectionDialogControllerOwner extends StatefulWidget {
  const _SectionDialogControllerOwner({
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_SectionDialogControllerOwner> createState() =>
      _SectionDialogControllerOwnerState();
}

class _SectionDialogControllerOwnerState
    extends State<_SectionDialogControllerOwner> {
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
