import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CatalogManagerPage extends ConsumerStatefulWidget {
  const CatalogManagerPage({super.key});

  @override
  ConsumerState<CatalogManagerPage> createState() => _CatalogManagerPageState();
}

class _CatalogManagerPageState extends ConsumerState<CatalogManagerPage> {
  late final _CatalogAdminApi _api;
  late Future<_CatalogSnapshot> _snapshotFuture;
  final TextEditingController _searchController = TextEditingController();
  String _catalogQuery = '';
  _CatalogFilter _catalogFilter = _CatalogFilter.all;

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _loadSnapshot();
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

  Future<void> _createCategory() async {
    final payload = await _showCategoryEditor();
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
    final payload = await _showCategoryEditor(existing: category);
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

  Future<void> _editSubcategory(_CatalogSnapshot snapshot, _AdminSubcategory subcategory) async {
    final payload = await _showSubcategoryEditor(snapshot, existing: subcategory);
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
      await _api.createService(payload);
      await _reload();
      await _showMessage('Service created');
    } catch (error) {
      await _showMessage('Unable to create service: $error');
    }
  }

  Future<void> _editService(_CatalogSnapshot snapshot, _AdminService service) async {
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

  Future<void> _bulkUpdateCategories(Iterable<_AdminCategory> categories, {required bool isActive}) async {
    final items = categories.toList(growable: false);
    if (items.isEmpty) return;
    try {
      for (final category in items) {
        await _api.updateCategory(category.id, {'isActive': isActive});
      }
      await _reload();
      await _showMessage('${items.length} categories ${isActive ? 'enabled' : 'disabled'}');
    } catch (error) {
      await _showMessage('Unable to update categories: $error');
    }
  }

  Future<void> _bulkUpdateSubcategories(Iterable<_AdminSubcategory> subcategories, {required bool isActive}) async {
    final items = subcategories.toList(growable: false);
    if (items.isEmpty) return;
    try {
      for (final subcategory in items) {
        await _api.updateSubcategory(subcategory.id, {'isActive': isActive});
      }
      await _reload();
      await _showMessage('${items.length} subcategories ${isActive ? 'enabled' : 'disabled'}');
    } catch (error) {
      await _showMessage('Unable to update subcategories: $error');
    }
  }

  Future<void> _bulkUpdateServices(Iterable<_AdminService> services, {required bool isActive}) async {
    final items = services.toList(growable: false);
    if (items.isEmpty) return;
    try {
      for (final service in items) {
        await _api.updateService(service.id, {'isActive': isActive});
      }
      await _reload();
      await _showMessage('${items.length} services ${isActive ? 'enabled' : 'disabled'}');
    } catch (error) {
      await _showMessage('Unable to update services: $error');
    }
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
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final category = ordered[index];
                    return ListTile(
                      tileColor: const Color(0xFFF9FAFB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE5E7EB),
                        child: Text('${index + 1}'),
                      ),
                      title: Text(category.name),
                      subtitle: Text(category.slug),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => setState(() {
                                    final item = ordered.removeAt(index);
                                    ordered.insert(index - 1, item);
                                  }),
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            onPressed: index == ordered.length - 1
                                ? null
                                : () => setState(() {
                                    final item = ordered.removeAt(index);
                                    ordered.insert(index + 1, item);
                                  }),
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                        ],
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
      await _api.reorderCategories(confirmed.map((category) => category.id).toList(growable: false));
      await _reload();
      await _showMessage('Category order updated');
    } catch (error) {
      await _showMessage('Unable to reorder categories: $error');
    }
  }

  Future<void> _reorderSubcategories(_CatalogSnapshot snapshot) async {
    if (snapshot.categories.isEmpty) return;
    final selectedCategoryId = ValueNotifier<String>(snapshot.categories.first.id);
    final ordered = ValueNotifier<List<_AdminSubcategory>>(snapshot.subcategoriesForCategory(snapshot.categories.first.id).toList(growable: true));

    final confirmed = await showDialog<_ReorderSelection<_AdminSubcategory>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final category = snapshot.categoryById(selectedCategoryId.value) ?? snapshot.categories.first;
            final categorySubcategories = snapshot.subcategoriesForCategory(category.id);
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
                          ordered.value = snapshot.subcategoriesForCategory(value).toList(growable: true);
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
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ordered.value.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = ordered.value[index];
                          return ListTile(
                            tileColor: const Color(0xFFF9FAFB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE5E7EB),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(item.name),
                            subtitle: Text('${item.serviceCount} services'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: index == 0
                                      ? null
                                      : () => setState(() {
                                          final moved = ordered.value.removeAt(index);
                                          ordered.value = [...ordered.value]..insert(index - 1, moved);
                                        }),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  onPressed: index == ordered.value.length - 1
                                      ? null
                                      : () => setState(() {
                                          final moved = ordered.value.removeAt(index);
                                          ordered.value = [...ordered.value]..insert(index + 1, moved);
                                        }),
                                  icon: const Icon(Icons.arrow_downward_rounded),
                                ),
                              ],
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
                    _ReorderSelection<_AdminSubcategory>(parentId: selectedCategoryId.value, items: ordered.value),
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
      await _api.reorderSubcategories(confirmed.parentId, confirmed.items.map((item) => item.id).toList(growable: false));
      await _reload();
      await _showMessage('Subcategory order updated');
    } catch (error) {
      await _showMessage('Unable to reorder subcategories: $error');
    }
  }

  Future<void> _reorderServices(_CatalogSnapshot snapshot) async {
    if (snapshot.subcategories.isEmpty) return;
    final selectedSubcategoryId = ValueNotifier<String>(snapshot.subcategories.first.id);
    final ordered = ValueNotifier<List<_AdminService>>(snapshot.servicesForSubcategory(snapshot.subcategories.first.id).toList(growable: true));

    final confirmed = await showDialog<_ReorderSelection<_AdminService>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategory = snapshot.subcategoryById(selectedSubcategoryId.value) ?? snapshot.subcategories.first;
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
                              child: Text('${snapshot.categoryById(item.categoryId)?.name ?? 'Category'} / ${item.name}'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedSubcategoryId.value = value;
                          ordered.value = snapshot.servicesForSubcategory(value).toList(growable: true);
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
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ordered.value.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = ordered.value[index];
                          return ListTile(
                            tileColor: const Color(0xFFF9FAFB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE5E7EB),
                              child: Text('${index + 1}'),
                            ),
                            title: Text(item.name),
                            subtitle: Text('₹${item.startingPrice.toStringAsFixed(0)} - ${item.estimatedDurationMins} mins'),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  onPressed: index == 0
                                      ? null
                                      : () => setState(() {
                                          final moved = ordered.value.removeAt(index);
                                          ordered.value = [...ordered.value]..insert(index - 1, moved);
                                        }),
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                ),
                                IconButton(
                                  onPressed: index == ordered.value.length - 1
                                      ? null
                                      : () => setState(() {
                                          final moved = ordered.value.removeAt(index);
                                          ordered.value = [...ordered.value]..insert(index + 1, moved);
                                        }),
                                  icon: const Icon(Icons.arrow_downward_rounded),
                                ),
                              ],
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
                    _ReorderSelection<_AdminService>(parentId: selectedSubcategoryId.value, items: ordered.value),
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
      await _api.reorderServices(confirmed.parentId, confirmed.items.map((item) => item.id).toList(growable: false));
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
                child: SelectableText(const JsonEncoder.withIndent('  ').convert(exportJson)),
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
    final controller = TextEditingController(text: const JsonEncoder.withIndent('  ').convert({
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

  Future<Map<String, dynamic>?> _showCategoryEditor({_AdminCategory? existing}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final sortOrderController = TextEditingController(text: (existing?.sortOrder ?? 0).toString());
    bool featured = existing?.featured ?? false;
    bool popular = existing?.popular ?? false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create category' : 'Edit category'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a category name' : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration: const InputDecoration(labelText: 'Sort order'),
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
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'sortOrder': int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
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
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final basePriceController = TextEditingController(text: (existing?.basePrice ?? 0).toStringAsFixed(0));
    final sortOrderController = TextEditingController(text: (existing?.sortOrder ?? 0).toString());

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(existing == null ? 'Create subcategory' : 'Edit subcategory'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: categoryIdController.value.isEmpty ? null : categoryIdController.value,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(() => categoryIdController.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a subcategory name' : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: basePriceController,
                        decoration: const InputDecoration(labelText: 'Base price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration: const InputDecoration(labelText: 'Sort order'),
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
                    Navigator.of(dialogContext).pop({
                      'categoryId': categoryIdController.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'basePrice': double.tryParse(basePriceController.text.trim()) ?? 0,
                      'sortOrder': int.tryParse(sortOrderController.text.trim()) ?? 0,
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
      existing?.subcategoryId ?? snapshot.subcategoriesForCategory(existing?.categoryId ?? snapshot.categories.firstOrNull?.id ?? '').firstOrNull?.id ?? '',
    );
    final nameController = TextEditingController(text: existing?.name ?? '');
    final slugController = TextEditingController(text: existing?.slug ?? '');
    final codeController = TextEditingController(text: existing?.code ?? '');
    final descriptionController = TextEditingController(text: existing?.description ?? '');
    final shortDescriptionController = TextEditingController(text: existing?.shortDescription ?? '');
    final startingPriceController = TextEditingController(text: (existing?.startingPrice ?? 0).toStringAsFixed(0));
    final gstRateController = TextEditingController(text: (existing?.gstRate ?? 18).toStringAsFixed(2));
    final sacCodeController = TextEditingController(text: existing?.sacCode ?? 'PENDING');
    final durationController = TextEditingController(text: (existing?.estimatedDurationMins ?? 0).toString());
    final warrantyController = TextEditingController(text: (existing?.warrantyDays ?? 0).toString());
    final iconController = TextEditingController(text: existing?.iconUrl ?? '');
    final seoTitleController = TextEditingController(text: existing?.seoTitle ?? '');
    final seoDescriptionController = TextEditingController(text: existing?.seoDescription ?? '');
    final seoKeywordsController = TextEditingController(text: existing?.seoKeywords ?? '');
    final cancellationPolicyController = TextEditingController(text: existing?.cancellationPolicy ?? '');
    final ratingController = TextEditingController(text: existing == null ? '0' : existing.rating.toStringAsFixed(2));
    final reviewCountController = TextEditingController(text: existing == null ? '0' : existing.reviewCount.toString());
    bool featured = existing?.featured ?? false;
    bool popular = existing?.popular ?? false;
    bool emergency = existing?.emergencyAvailable ?? false;
    bool homeVisit = existing?.homeVisit ?? true;
    bool requiresSiteVisit = existing?.requiresSiteVisit ?? false;
    bool isActive = existing?.isActive ?? true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategories = snapshot.subcategoriesForCategory(selectedCategoryId.value);
            if (selectedSubcategoryId.value.isEmpty && subcategories.isNotEmpty) {
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
                        initialValue: selectedCategoryId.value.isEmpty ? null : selectedCategoryId.value,
                        decoration: const InputDecoration(labelText: 'Category'),
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
                            final nextSubcategories = snapshot.subcategoriesForCategory(selectedCategoryId.value);
                            selectedSubcategoryId.value = nextSubcategories.firstOrNull?.id ?? '';
                          });
                        },
                        validator: (value) => (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubcategoryId.value.isEmpty ? null : selectedSubcategoryId.value,
                        decoration: const InputDecoration(labelText: 'Subcategory'),
                        items: subcategories
                            .map(
                              (subcategory) => DropdownMenuItem(
                                value: subcategory.id,
                                child: Text(subcategory.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(() => selectedSubcategoryId.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty ? 'Select a subcategory' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a service name' : null,
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
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: shortDescriptionController,
                        decoration: const InputDecoration(labelText: 'Short description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: startingPriceController,
                        decoration: const InputDecoration(labelText: 'Starting price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: gstRateController,
                        decoration: const InputDecoration(labelText: 'GST rate (%)'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sacCodeController,
                        decoration: const InputDecoration(labelText: 'SAC code'),
                      ),
                      TextFormField(
                        controller: durationController,
                        decoration: const InputDecoration(labelText: 'Estimated duration (mins)'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyController,
                        decoration: const InputDecoration(labelText: 'Warranty days'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: iconController,
                        decoration: const InputDecoration(labelText: 'Icon URL'),
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration: const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration: const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: seoKeywordsController,
                        decoration: const InputDecoration(labelText: 'SEO keywords'),
                      ),
                      TextFormField(
                        controller: cancellationPolicyController,
                        decoration: const InputDecoration(labelText: 'Cancellation policy'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration: const InputDecoration(labelText: 'Review count'),
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
                        onChanged: (value) => setState(() => requiresSiteVisit = value),
                        title: const Text('Requires site visit (Big Job)'),
                        subtitle: const Text('Worker visits first to generate a custom quote'),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
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
                    Navigator.of(dialogContext).pop({
                      'categoryId': selectedCategoryId.value,
                      'subcategoryId': selectedSubcategoryId.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'code': codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'shortDescription': shortDescriptionController.text.trim().isEmpty
                          ? null
                          : shortDescriptionController.text.trim(),
                      'startingPrice': double.tryParse(startingPriceController.text.trim()) ?? 0,
                      'gstRate': double.tryParse(gstRateController.text.trim()) ?? 18,
                      'sacCode': sacCodeController.text.trim().isEmpty ? 'PENDING' : sacCodeController.text.trim(),
                      'estimatedDurationMins': int.tryParse(durationController.text.trim()) ?? 0,
                      'warrantyDays': int.tryParse(warrantyController.text.trim()) ?? 0,
                      'iconUrl': iconController.text.trim().isEmpty ? null : iconController.text.trim(),
                      'seoTitle': seoTitleController.text.trim().isEmpty ? null : seoTitleController.text.trim(),
                      'seoDescription': seoDescriptionController.text.trim().isEmpty
                          ? null
                          : seoDescriptionController.text.trim(),
                      'seoKeywords': seoKeywordsController.text.trim().isEmpty ? null : seoKeywordsController.text.trim(),
                      'cancellationPolicy': cancellationPolicyController.text.trim().isEmpty
                          ? null
                          : cancellationPolicyController.text.trim(),
                      'rating': double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount': int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'emergencyAvailable': emergency,
                      'homeVisit': homeVisit,
                      'requiresSiteVisit': requiresSiteVisit,
                      'isActive': isActive,
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
      startingPriceController.dispose();
      gstRateController.dispose();
      sacCodeController.dispose();
      durationController.dispose();
      warrantyController.dispose();
      iconController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      seoKeywordsController.dispose();
      cancellationPolicyController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
    });
  }

  Future<Map<String, dynamic>?> _showPricingRuleEditor(_AdminService service) {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: 'BASE');
    final titleController = TextEditingController(text: '${service.name} base price');
    final cityIdController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController(text: service.startingPrice.toStringAsFixed(0));
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
                      DropdownMenuItem(value: 'SEASONAL', child: Text('SEASONAL')),
                      DropdownMenuItem(value: 'PROMOTIONAL', child: Text('PROMOTIONAL')),
                      DropdownMenuItem(value: 'SURGE', child: Text('SURGE')),
                      DropdownMenuItem(value: 'WORKER', child: Text('WORKER')),
                    ],
                    onChanged: (value) => typeController.text = value ?? 'BASE',
                  ),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a title' : null,
                  ),
                  TextFormField(
                    controller: cityIdController,
                    decoration: const InputDecoration(labelText: 'City ID (optional)'),
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
                Navigator.of(dialogContext).pop({
                  'type': typeController.text,
                  'title': titleController.text.trim(),
                  'cityId': cityIdController.text.trim().isEmpty ? null : cityIdController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                  'currency': 'INR',
                  'price': double.tryParse(priceController.text.trim()) ?? service.startingPrice,
                  'priority': int.tryParse(priorityController.text.trim()) ?? 0,
                });
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
              final loading = snapshot.connectionState == ConnectionState.waiting;
              final data = snapshot.data;
              final visibleCategories = data == null ? const <_AdminCategory>[] : _filteredCategories(data, _catalogQuery, _catalogFilter);
              final visibleSubcategories = data == null ? const <_AdminSubcategory>[] : _filteredSubcategories(data, _catalogQuery, _catalogFilter);
              final visibleServices = data == null ? const <_AdminService>[] : _filteredServices(data, _catalogQuery, _catalogFilter);

              return Column(
                children: [
                  Padding(
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
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Manage categories, services, pricing, images, and bulk imports without code changes.',
                                    style: GoogleFonts.inter(
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
                              onPressed: loading ? null : () => _createService(data ?? const _CatalogSnapshot.empty()),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('New service'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SearchBar(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _catalogQuery = value.trim()),
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
                                  onSelected: (_) => setState(() => _catalogFilter = filter),
                                ),
                              )
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 12),
                        if (!loading && data != null) _OverviewMetrics(snapshot: data),
                        const SizedBox(height: 18),
                        const TabBar(
                          isScrollable: true,
                          tabs: [
                            Tab(text: 'Categories'),
                            Tab(text: 'Subcategories'),
                            Tab(text: 'Services'),
                            Tab(text: 'Pricing'),
                            Tab(text: 'Import/Export'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: loading && data == null
                        ? const Center(child: CircularProgressIndicator())
                        : data == null
                            ? _ErrorState(onRetry: _reload)
                            : TabBarView(
                                children: [
                                  _CategoriesTab(
                                    snapshot: data,
                                    query: _catalogQuery,
                                    filter: _catalogFilter,
                                    visibleCount: visibleCategories.length,
                                    onCreate: _createCategory,
                                    onEdit: _editCategory,
                                    onDisable: _toggleCategory,
                                    onReorder: () => _reorderCategories(data),
                                    onBulkEnable: () => _bulkUpdateCategories(visibleCategories, isActive: true),
                                    onBulkDisable: () => _bulkUpdateCategories(visibleCategories, isActive: false),
                                  ),
                                  _SubcategoriesTab(
                                    snapshot: data,
                                    query: _catalogQuery,
                                    filter: _catalogFilter,
                                    visibleCount: visibleSubcategories.length,
                                    onCreate: () => _createSubcategory(data),
                                    onEdit: (subcategory) => _editSubcategory(data, subcategory),
                                    onDisable: _toggleSubcategory,
                                    onReorder: () => _reorderSubcategories(data),
                                    onBulkEnable: () => _bulkUpdateSubcategories(visibleSubcategories, isActive: true),
                                    onBulkDisable: () => _bulkUpdateSubcategories(visibleSubcategories, isActive: false),
                                  ),
                                  _ServicesTab(
                                    snapshot: data,
                                    query: _catalogQuery,
                                    filter: _catalogFilter,
                                    visibleCount: visibleServices.length,
                                    onCreate: () => _createService(data),
                                    onEdit: (service) => _editService(data, service),
                                    onDisable: _toggleService,
                                    onPricingRule: _addPricingRule,
                                    onReorder: () => _reorderServices(data),
                                    onBulkEnable: () => _bulkUpdateServices(visibleServices, isActive: true),
                                    onBulkDisable: () => _bulkUpdateServices(visibleServices, isActive: false),
                                  ),
                                  _PricingTab(
                                    snapshot: data,
                                    query: _catalogQuery,
                                    filter: _catalogFilter,
                                    onPricingRule: _addPricingRule,
                                  ),
                                  _ImportExportTab(
                                    onImport: _importCatalog,
                                    onExport: _exportCatalog,
                                  ),
                                ],
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
          hintText: 'Search category, subcategory, service, or slug',
        ),
        style: GoogleFonts.inter(
          color: Colors.black87,
          fontSize: 15,
        ),
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
    final activeServices = snapshot.services.where((service) => service.isActive).length;
    final metrics = <_MetricData>[
      _MetricData(label: 'Categories', value: totalCategories.toString(), icon: Icons.category_rounded, accent: const Color(0xFF6366F1)),
      _MetricData(label: 'Subcategories', value: totalSubcategories.toString(), icon: Icons.view_module_rounded, accent: const Color(0xFF38BDF8)),
      _MetricData(label: 'Services', value: totalServices.toString(), icon: Icons.design_services_rounded, accent: const Color(0xFF10B981)),
      _MetricData(label: 'Active', value: activeServices.toString(), icon: Icons.verified_rounded, accent: const Color(0xFFF59E0B)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics
          .map(
            (metric) => SizedBox(
              width: 180,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: AbzioTheme.eliteShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: metric.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(metric.icon, color: metric.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.value,
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            metric.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
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

List<_AdminCategory> _filteredCategories(_CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
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

List<_AdminSubcategory> _filteredSubcategories(_CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
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

List<_AdminService> _filteredServices(_CatalogSnapshot snapshot, String query, _CatalogFilter filter) {
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category management',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create, edit, disable, and reorder main service categories.',
              style: GoogleFonts.inter(
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
                '${category.subcategories.length} subcategories - ${category.serviceCount} services',
            tag: category.isActive ? 'Active' : 'Disabled',
            accent: category.featured ? const Color(0xFFC2A15E) : const Color(0xFF10B981),
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subcategory management',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Assign pricing, icons, translations, and active status.',
              style: GoogleFonts.inter(
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
                  '${category?.name ?? 'Category'} - ${subcategory.serviceCount} services - ₹${subcategory.basePrice.toStringAsFixed(0)} base',
              tag: subcategory.isActive ? 'Active' : 'Disabled',
              accent: const Color(0xFF38BDF8),
              onTap: () => context.push('/catalog/subcategories/${subcategory.id}'),
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
  });

  final _CatalogSnapshot snapshot;
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Service management',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Edit descriptions, images, durations, skills, and SEO metadata.',
              style: GoogleFonts.inter(
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
        const SizedBox(height: 16),
        ...snapshot.services.where((service) {
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
        }).map(
          (service) {
            final category = snapshot.categoryById(service.categoryId);
            final subcategory = snapshot.subcategoryById(service.subcategoryId);
            return _CatalogCard(
              title: service.name,
              subtitle:
                  '${category?.name ?? 'Category'} / ${subcategory?.name ?? 'Subcategory'} - ₹${service.startingPrice.toStringAsFixed(0)} - GST ${service.gstRate.toStringAsFixed(2)}% - SAC ${service.sacCode} - ${service.estimatedDurationMins} mins',
              tag: service.isActive ? 'Active' : 'Disabled',
              accent: service.featured ? const Color(0xFFC2A15E) : const Color(0xFF10B981),
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
    required this.query,
    required this.filter,
    required this.onPricingRule,
  });

  final _CatalogSnapshot snapshot;
  final String query;
  final _CatalogFilter filter;
  final ValueChanged<_AdminService> onPricingRule;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing management',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Maintain base, city, seasonal, promotional, and worker-level pricing.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...snapshot.services.where((service) {
          return _matchesCatalogFilter(
                isActive: service.isActive,
                featured: service.featured,
                popular: service.popular,
                filter: filter,
              ) &&
              _matchesQuery([
                service.name,
                service.slug,
                snapshot.subcategoryById(service.subcategoryId)?.name ?? '',
              ], query);
        }).map(
          (service) => _CatalogCard(
            title: service.name,
            subtitle:
                'Base price ₹${service.startingPrice.toStringAsFixed(0)} - GST ${service.gstRate.toStringAsFixed(2)}% - SAC ${service.sacCode} - ${service.pricingRules.length} rules',
            tag: 'Pricing',
            accent: const Color(0xFFF59E0B),
            onTap: () => context.push('/catalog/services/${service.id}'),
            onEdit: () => onPricingRule(service),
            onDisable: () {},
            secondaryLabel: 'Add rule',
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
  });

  final VoidCallback onImport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import and export',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use JSON import jobs to manage large catalog updates safely.',
              style: GoogleFonts.inter(
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
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Import accepts the hierarchical JSON structure used by the catalog seed and admin export flow. This lets the team manage 200+ services without code changes.',
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
    this.secondaryLabel = 'Disable',
  });

  final String title;
  final String subtitle;
  final String tag;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDisable;
  final Widget? trailing;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: AbzioTheme.eliteShadow,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Icon(Icons.grid_view_rounded, color: accent),
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
                  IconButton(
                    onPressed: onDisable,
                    icon: const Icon(Icons.visibility_off_rounded),
                    tooltip: secondaryLabel,
                  ),
                ],
              ),
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
        borderRadius: BorderRadius.circular(999),
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

  Future<({_CatalogSnapshot snapshot, _AdminCategory category})?> _load() async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _showCategoryEditor(_AdminCategory existing) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final descriptionController = TextEditingController(text: existing.description ?? '');
    final iconUrlController = TextEditingController(text: existing.iconUrl ?? '');
    final seoTitleController = TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController = TextEditingController(text: existing.seoDescription ?? '');
    final sortOrderController = TextEditingController(text: existing.sortOrder.toString());
    var featured = existing.featured;
    var popular = existing.popular;
    var isActive = existing.isActive;

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
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a category name' : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: iconUrlController,
                        decoration: const InputDecoration(labelText: 'Icon URL'),
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration: const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration: const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration: const InputDecoration(labelText: 'Sort order'),
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
                    Navigator.of(dialogContext).pop({
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'iconUrl': iconUrlController.text.trim().isEmpty ? null : iconUrlController.text.trim(),
                      'seoTitle': seoTitleController.text.trim().isEmpty ? null : seoTitleController.text.trim(),
                      'seoDescription': seoDescriptionController.text.trim().isEmpty ? null : seoDescriptionController.text.trim(),
                      'sortOrder': int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'isActive': isActive,
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
      iconUrlController.dispose();
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
      await _showMessage(category.isActive ? 'Category disabled' : 'Category enabled');
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
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<({_CatalogSnapshot snapshot, _AdminCategory category})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load category: ${snapshot.error}'));
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
                    Text('Category not found', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This category is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Reload')),
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
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.category_rounded, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(category.slug, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                    icon: Icon(category.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    label: Text(category.isActive ? 'Disable' : 'Enable'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(label: category.featured ? 'Featured' : 'Standard'),
                  _DetailChip(label: category.popular ? 'Popular' : 'Not popular'),
                  _DetailChip(label: '${category.subcategories.length} subcategories'),
                  _DetailChip(label: '${category.serviceCount} services'),
                ],
              ),
              const SizedBox(height: 18),
              if ((category.description ?? '').trim().isNotEmpty) ...[
                Text('Description', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(category.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((category.iconUrl ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'Icon URL', value: category.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((category.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO title', value: category.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((category.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO description', value: category.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(label: 'Category ID', value: category.id),
              _DetailLine(label: 'Slug', value: category.slug),
              _DetailLine(label: 'Status', value: category.isActive ? 'Active' : 'Disabled'),
              _DetailLine(label: 'Sort order', value: '${category.sortOrder}'),
              const SizedBox(height: 18),
              Text('Subcategories', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...category.subcategories.map(
                (subcategory) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(subcategory.name),
                    subtitle: Text('${subcategory.services.length} services - ₹${subcategory.basePrice.toStringAsFixed(0)} base'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/catalog/subcategories/${subcategory.id}'),
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
  ConsumerState<SubcategoryDetailPage> createState() => _SubcategoryDetailPageState();
}

class _SubcategoryDetailPageState extends ConsumerState<SubcategoryDetailPage> {
  late final _CatalogAdminApi _api;
  late Future<({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?> _future;

  @override
  void initState() {
    super.initState();
    _api = _CatalogAdminApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?> _load() async {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _showSubcategoryEditor(_CatalogSnapshot snapshot, _AdminSubcategory existing) {
    final formKey = GlobalKey<FormState>();
    final categoryIdController = ValueNotifier<String>(existing.categoryId);
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final descriptionController = TextEditingController(text: existing.description ?? '');
    final iconUrlController = TextEditingController(text: existing.iconUrl ?? '');
    final seoTitleController = TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController = TextEditingController(text: existing.seoDescription ?? '');
    final basePriceController = TextEditingController(text: existing.basePrice.toStringAsFixed(0));
    final sortOrderController = TextEditingController(text: existing.sortOrder.toString());
    final ratingController = TextEditingController(text: existing.rating.toStringAsFixed(1));
    final reviewCountController = TextEditingController(text: existing.reviewCount.toString());
    var isActive = existing.isActive;

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
                        initialValue: categoryIdController.value.isEmpty ? null : categoryIdController.value,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: snapshot.categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(() => categoryIdController.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a subcategory name' : null,
                      ),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(labelText: 'Slug'),
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: iconUrlController,
                        decoration: const InputDecoration(labelText: 'Icon URL'),
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration: const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration: const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: basePriceController,
                        decoration: const InputDecoration(labelText: 'Base price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sortOrderController,
                        decoration: const InputDecoration(labelText: 'Sort order'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration: const InputDecoration(labelText: 'Review count'),
                        keyboardType: TextInputType.number,
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
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
                    Navigator.of(dialogContext).pop({
                      'categoryId': categoryIdController.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'iconUrl': iconUrlController.text.trim().isEmpty ? null : iconUrlController.text.trim(),
                      'seoTitle': seoTitleController.text.trim().isEmpty ? null : seoTitleController.text.trim(),
                      'seoDescription': seoDescriptionController.text.trim().isEmpty ? null : seoDescriptionController.text.trim(),
                      'basePrice': double.tryParse(basePriceController.text.trim()) ?? 0,
                      'sortOrder': int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'rating': double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount': int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'isActive': isActive,
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
      iconUrlController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      basePriceController.dispose();
      sortOrderController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
    });
  }

  Future<void> _editSubcategory(_CatalogSnapshot snapshot, _AdminSubcategory subcategory) async {
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
      await _api.updateSubcategory(subcategory.id, {'isActive': !subcategory.isActive});
      await _reload();
      await _showMessage(subcategory.isActive ? 'Subcategory disabled' : 'Subcategory enabled');
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
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<({_CatalogSnapshot snapshot, _AdminSubcategory subcategory})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load subcategory: ${snapshot.error}'));
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
                    Text('Subcategory not found', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This subcategory is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Reload')),
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
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.layers_rounded, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subcategory.name, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text(category?.name ?? 'Category', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (!subcategory.isActive) const _DetailBadge(label: 'Disabled'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _editSubcategory(data.snapshot, subcategory),
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit subcategory'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _toggleSubcategory(subcategory),
                    icon: Icon(subcategory.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded),
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
                  _DetailChip(label: '₹${subcategory.basePrice.toStringAsFixed(0)} base'),
                  _DetailChip(label: 'Rating ${subcategory.rating.toStringAsFixed(1)}'),
                  _DetailChip(label: '${subcategory.reviewCount} reviews'),
                  _DetailChip(label: subcategory.isActive ? 'Active' : 'Disabled'),
                ],
              ),
              const SizedBox(height: 18),
              if ((subcategory.description ?? '').trim().isNotEmpty) ...[
                Text('Description', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subcategory.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((subcategory.iconUrl ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'Icon URL', value: subcategory.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((subcategory.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO title', value: subcategory.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((subcategory.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO description', value: subcategory.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(label: 'Rating', value: subcategory.rating.toStringAsFixed(1)),
              _DetailLine(label: 'Review count', value: '${subcategory.reviewCount}'),
              _DetailLine(label: 'Subcategory ID', value: subcategory.id),
              _DetailLine(label: 'Category', value: category?.name ?? 'Unknown'),
              _DetailLine(label: 'Slug', value: subcategory.slug),
              _DetailLine(label: 'Base price', value: '₹${subcategory.basePrice.toStringAsFixed(0)}'),
              _DetailLine(label: 'Status', value: subcategory.isActive ? 'Active' : 'Disabled'),
              _DetailLine(label: 'Sort order', value: '${subcategory.sortOrder}'),
              const SizedBox(height: 18),
              Text('Services', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...subcategory.services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(service.name),
                    subtitle: Text('₹${service.startingPrice.toStringAsFixed(0)} - ${service.estimatedDurationMins} mins'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/catalog/services/${service.id}'),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _showServiceEditor(_CatalogSnapshot snapshot, _AdminService existing) {
    final formKey = GlobalKey<FormState>();
    final selectedCategoryId = ValueNotifier<String>(existing.categoryId);
    final selectedSubcategoryId = ValueNotifier<String>(existing.subcategoryId);
    final nameController = TextEditingController(text: existing.name);
    final slugController = TextEditingController(text: existing.slug);
    final codeController = TextEditingController(text: existing.code ?? '');
    final descriptionController = TextEditingController(text: existing.description ?? '');
    final shortDescriptionController = TextEditingController(text: existing.shortDescription ?? '');
    final startingPriceController = TextEditingController(text: existing.startingPrice.toStringAsFixed(0));
    final gstRateController = TextEditingController(text: existing.gstRate.toStringAsFixed(2));
    final sacCodeController = TextEditingController(text: existing.sacCode);
    final durationController = TextEditingController(text: existing.estimatedDurationMins.toString());
    final warrantyController = TextEditingController(text: existing.warrantyDays.toString());
    final iconController = TextEditingController(text: existing.iconUrl ?? '');
    final seoTitleController = TextEditingController(text: existing.seoTitle ?? '');
    final seoDescriptionController = TextEditingController(text: existing.seoDescription ?? '');
    final seoKeywordsController = TextEditingController(text: existing.seoKeywords ?? '');
    final cancellationPolicyController = TextEditingController(text: existing.cancellationPolicy ?? '');
    final ratingController = TextEditingController(text: existing.rating.toStringAsFixed(2));
    final reviewCountController = TextEditingController(text: existing.reviewCount.toString());
    var featured = existing.featured;
    var popular = existing.popular;
    var emergency = existing.emergencyAvailable;
    var homeVisit = existing.homeVisit;
    var requiresSiteVisit = existing.requiresSiteVisit;
    var isActive = existing.isActive;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final subcategories = snapshot.subcategoriesForCategory(selectedCategoryId.value);
            if (subcategories.isNotEmpty && !subcategories.any((item) => item.id == selectedSubcategoryId.value)) {
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
                        initialValue: selectedCategoryId.value.isEmpty ? null : selectedCategoryId.value,
                        decoration: const InputDecoration(labelText: 'Category'),
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
                            final next = snapshot.subcategoriesForCategory(selectedCategoryId.value);
                            selectedSubcategoryId.value = next.firstOrNull?.id ?? '';
                          });
                        },
                        validator: (value) => (value ?? '').isEmpty ? 'Select a category' : null,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubcategoryId.value.isEmpty ? null : selectedSubcategoryId.value,
                        decoration: const InputDecoration(labelText: 'Subcategory'),
                        items: subcategories
                            .map(
                              (subcategory) => DropdownMenuItem(
                                value: subcategory.id,
                                child: Text(subcategory.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) => setState(() => selectedSubcategoryId.value = value ?? ''),
                        validator: (value) => (value ?? '').isEmpty ? 'Select a subcategory' : null,
                      ),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) => (value ?? '').trim().length < 2 ? 'Enter a service name' : null,
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
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: shortDescriptionController,
                        decoration: const InputDecoration(labelText: 'Short description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: startingPriceController,
                        decoration: const InputDecoration(labelText: 'Starting price'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: gstRateController,
                        decoration: const InputDecoration(labelText: 'GST rate'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: sacCodeController,
                        decoration: const InputDecoration(labelText: 'SAC code'),
                      ),
                      TextFormField(
                        controller: durationController,
                        decoration: const InputDecoration(labelText: 'Duration (mins)'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: warrantyController,
                        decoration: const InputDecoration(labelText: 'Warranty days'),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: iconController,
                        decoration: const InputDecoration(labelText: 'Icon URL'),
                      ),
                      TextFormField(
                        controller: seoTitleController,
                        decoration: const InputDecoration(labelText: 'SEO title'),
                      ),
                      TextFormField(
                        controller: seoDescriptionController,
                        decoration: const InputDecoration(labelText: 'SEO description'),
                        maxLines: 2,
                      ),
                      TextFormField(
                        controller: seoKeywordsController,
                        decoration: const InputDecoration(labelText: 'SEO keywords'),
                      ),
                      TextFormField(
                        controller: cancellationPolicyController,
                        decoration: const InputDecoration(labelText: 'Cancellation policy'),
                        maxLines: 3,
                      ),
                      TextFormField(
                        controller: ratingController,
                        decoration: const InputDecoration(labelText: 'Rating'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      TextFormField(
                        controller: reviewCountController,
                        decoration: const InputDecoration(labelText: 'Review count'),
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
                        onChanged: (value) => setState(() => requiresSiteVisit = value),
                        title: const Text('Requires site visit (Big Job)'),
                        subtitle: const Text('Worker visits first to generate a custom quote'),
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (value) => setState(() => isActive = value),
                        title: const Text('Active'),
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
                    Navigator.of(dialogContext).pop({
                      'categoryId': selectedCategoryId.value,
                      'subcategoryId': selectedSubcategoryId.value,
                      'name': nameController.text.trim(),
                      'slug': slugController.text.trim().isEmpty ? _slugify(nameController.text) : slugController.text.trim(),
                      'code': codeController.text.trim().isEmpty ? null : codeController.text.trim(),
                      'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                      'shortDescription': shortDescriptionController.text.trim().isEmpty ? null : shortDescriptionController.text.trim(),
                      'startingPrice': double.tryParse(startingPriceController.text.trim()) ?? 0,
                      'gstRate': double.tryParse(gstRateController.text.trim()) ?? 0,
                      'sacCode': sacCodeController.text.trim().isEmpty ? null : sacCodeController.text.trim(),
                      'estimatedDurationMins': int.tryParse(durationController.text.trim()) ?? 0,
                      'warrantyDays': int.tryParse(warrantyController.text.trim()) ?? 0,
                      'iconUrl': iconController.text.trim().isEmpty ? null : iconController.text.trim(),
                      'seoTitle': seoTitleController.text.trim().isEmpty ? null : seoTitleController.text.trim(),
                      'seoDescription': seoDescriptionController.text.trim().isEmpty
                          ? null
                          : seoDescriptionController.text.trim(),
                      'seoKeywords': seoKeywordsController.text.trim().isEmpty ? null : seoKeywordsController.text.trim(),
                      'cancellationPolicy': cancellationPolicyController.text.trim().isEmpty
                          ? null
                          : cancellationPolicyController.text.trim(),
                      'rating': double.tryParse(ratingController.text.trim()) ?? 0,
                      'reviewCount': int.tryParse(reviewCountController.text.trim()) ?? 0,
                      'featured': featured,
                      'popular': popular,
                      'emergencyAvailable': emergency,
                      'homeVisit': homeVisit,
                      'requiresSiteVisit': requiresSiteVisit,
                      'isActive': isActive,
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
      startingPriceController.dispose();
      gstRateController.dispose();
      sacCodeController.dispose();
      durationController.dispose();
      warrantyController.dispose();
      iconController.dispose();
      seoTitleController.dispose();
      seoDescriptionController.dispose();
      seoKeywordsController.dispose();
      cancellationPolicyController.dispose();
      ratingController.dispose();
      reviewCountController.dispose();
    });
  }

  Future<void> _editService(_CatalogSnapshot snapshot, _AdminService service) async {
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
      await _showMessage(service.isActive ? 'Service disabled' : 'Service enabled');
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
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: FutureBuilder<({_CatalogSnapshot snapshot, _AdminService service})?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load service: ${snapshot.error}'));
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
                    Text('Service not found', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This service is not present in the current catalog snapshot.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Reload')),
                  ],
                ),
              ),
            );
          }

          final service = data.service;
          final category = data.snapshot.categoryById(service.categoryId);
          final subcategory = data.snapshot.subcategoryById(service.subcategoryId);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: service.featured ? const Color(0xFFC2A15E).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.design_services_rounded,
                      color: service.featured ? const Color(0xFFC2A15E) : const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.name, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        Text('${category?.name ?? 'Category'} / ${subcategory?.name ?? 'Subcategory'}', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                  _DetailChip(label: '₹${service.startingPrice.toStringAsFixed(0)}'),
                  _DetailChip(label: '${service.estimatedDurationMins} mins'),
                  _DetailChip(label: 'GST ${service.gstRate.toStringAsFixed(2)}%'),
                  _DetailChip(label: 'SAC ${service.sacCode}'),
                  _DetailChip(label: 'Rating ${service.rating.toStringAsFixed(1)}'),
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
                    icon: Icon(service.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    label: Text(service.isActive ? 'Disable' : 'Enable'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if ((service.description ?? '').trim().isNotEmpty) ...[
                Text('Description', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(service.description!.trim()),
                const SizedBox(height: 18),
              ],
              if ((service.shortDescription ?? '').trim().isNotEmpty) ...[
                Text('Short Description', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(service.shortDescription!.trim()),
                const SizedBox(height: 18),
              ],
              if ((service.iconUrl ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'Icon URL', value: service.iconUrl!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoTitle ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO title', value: service.seoTitle!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoDescription ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO description', value: service.seoDescription!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.seoKeywords ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'SEO keywords', value: service.seoKeywords!.trim()),
                const SizedBox(height: 8),
              ],
              if ((service.cancellationPolicy ?? '').trim().isNotEmpty) ...[
                _DetailLine(label: 'Cancellation policy', value: service.cancellationPolicy!.trim()),
                const SizedBox(height: 8),
              ],
              _DetailLine(label: 'Rating', value: service.rating.toStringAsFixed(1)),
              _DetailLine(label: 'Review count', value: '${service.reviewCount}'),
              _DetailLine(label: 'Service ID', value: service.id),
              _DetailLine(label: 'Category', value: category?.name ?? 'Unknown'),
              _DetailLine(label: 'Subcategory', value: subcategory?.name ?? 'Unknown'),
              _DetailLine(label: 'Slug', value: service.slug),
              _DetailLine(label: 'Code', value: service.code ?? 'None'),
              _DetailLine(label: 'Duration', value: '${service.estimatedDurationMins} mins'),
              _DetailLine(label: 'Home visit', value: service.homeVisit ? 'Yes' : 'No'),
              _DetailLine(label: 'Featured', value: service.featured ? 'Yes' : 'No'),
              _DetailLine(label: 'Status', value: service.isActive ? 'Active' : 'Disabled'),
              const SizedBox(height: 18),
              Text('Pricing Rules', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (service.pricingRules.isEmpty)
                Text('No pricing rules configured yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
              else
                ...service.pricingRules.map(
                  (rule) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(rule.title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
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
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
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
        color: const Color(0xFF94A3B8).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700)),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
    final response = await _dio.get<Map<String, dynamic>>(
      '/catalog',
      queryParameters: {'includeInactive': true},
    );
    final rawCategories = (response.data?['categories'] as List?) ?? const [];
    final summaryCategories = rawCategories.whereType<Map<String, dynamic>>().map(_AdminCategory.fromSummary).toList();
    final detailed = <_AdminCategory>[];
    for (final category in summaryCategories) {
      final detailResponse = await _dio.get<Map<String, dynamic>>('/catalog/categories/${category.slug}');
      final categoryJson = (detailResponse.data?['category'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      detailed.add(_AdminCategory.fromDetail(categoryJson, fallback: category));
    }
    return _CatalogSnapshot(categories: detailed);
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

  Future<void> createService(Map<String, dynamic> data) async {
    await _dio.post('/admin/catalog/services', data: data);
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

  Future<void> addPricingRule(String serviceId, Map<String, dynamic> data) async {
    await _dio.post('/admin/catalog/services/$serviceId/pricing-rules', data: data);
  }

  Future<Map<String, dynamic>> exportCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/catalog/export');
    return response.data ?? <String, dynamic>{};
  }

  Future<void> importCatalog(List<dynamic> categories) async {
    await _dio.post('/admin/catalog/import', data: {'categories': categories});
  }
}

class _CatalogSnapshot {
  const _CatalogSnapshot({required this.categories});

  const _CatalogSnapshot.empty() : categories = const [];

  final List<_AdminCategory> categories;

  List<_AdminSubcategory> get subcategories => categories.expand((category) => category.subcategories).toList(growable: false);

  List<_AdminService> get services => subcategories.expand((subcategory) => subcategory.services).toList(growable: false);

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
  final List<_AdminSubcategory> subcategories;

  int get serviceCount => subcategories.fold<int>(0, (sum, subcategory) => sum + subcategory.serviceCount);

  factory _AdminCategory.fromSummary(Map<String, dynamic> json) {
    return _AdminCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      subcategories: const [],
    );
  }

  factory _AdminCategory.fromDetail(Map<String, dynamic> json, {_AdminCategory? fallback}) {
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
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? fallback?.sortOrder ?? 0,
      description: json['description'] as String? ?? fallback?.description,
      iconUrl: json['iconUrl'] as String? ?? fallback?.iconUrl,
      seoTitle: json['seoTitle'] as String? ?? fallback?.seoTitle,
      seoDescription: json['seoDescription'] as String? ?? fallback?.seoDescription,
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
  final List<_AdminService> services;

  int get serviceCount => services.length;

  factory _AdminSubcategory.fromJson(Map<String, dynamic> json) {
    final servicesJson = (json['catalogServices'] as List? ?? json['services'] as List? ?? const []);
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
      services: servicesJson.whereType<Map<String, dynamic>>().map(_AdminService.fromJson).toList(growable: false),
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
    required this.sacCode,
    required this.estimatedDurationMins,
    required this.isActive,
    required this.featured,
    required this.popular,
    required this.emergencyAvailable,
    required this.homeVisit,
    required this.requiresSiteVisit,
    required this.warrantyDays,
    required this.description,
    required this.shortDescription,
    required this.iconUrl,
    required this.seoTitle,
    required this.seoDescription,
    required this.seoKeywords,
    required this.cancellationPolicy,
    required this.rating,
    required this.reviewCount,
    required this.pricingRules,
  });

  final String id;
  final String categoryId;
  final String subcategoryId;
  final String name;
  final String slug;
  final String? code;
  final double startingPrice;
  final double gstRate;
  final String sacCode;
  final int estimatedDurationMins;
  final bool isActive;
  final bool featured;
  final bool popular;
  final bool emergencyAvailable;
  final bool homeVisit;
  final bool requiresSiteVisit;
  final int warrantyDays;
  final String? description;
  final String? shortDescription;
  final String? iconUrl;
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
  final String? cancellationPolicy;
  final double rating;
  final int reviewCount;
  final List<_AdminPricingRule> pricingRules;

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
      sacCode: (json['sacCode'] as String?)?.trim().isNotEmpty == true ? json['sacCode'] as String : 'PENDING',
      estimatedDurationMins: (json['estimatedDurationMins'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      featured: json['featured'] as bool? ?? false,
      popular: json['popular'] as bool? ?? false,
      emergencyAvailable: json['emergencyAvailable'] as bool? ?? false,
      homeVisit: json['homeVisit'] as bool? ?? true,
      requiresSiteVisit: json['requiresSiteVisit'] as bool? ?? false,
      warrantyDays: (json['warrantyDays'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      shortDescription: json['shortDescription'] as String?,
      iconUrl: json['iconUrl'] as String?,
      seoTitle: json['seoTitle'] as String?,
      seoDescription: json['seoDescription'] as String?,
      seoKeywords: json['seoKeywords'] as String?,
      cancellationPolicy: json['cancellationPolicy'] as String?,
      rating: _toDouble(json['rating']),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      pricingRules: (json['pricingRules'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_AdminPricingRule.fromJson)
          .toList(growable: false),
    );
  }
}

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

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
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
