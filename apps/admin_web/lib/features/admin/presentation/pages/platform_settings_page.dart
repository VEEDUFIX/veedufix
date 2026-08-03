import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../widgets/admin_surface.dart';

class PlatformSettingsPage extends ConsumerStatefulWidget {
  const PlatformSettingsPage({super.key});

  @override
  ConsumerState<PlatformSettingsPage> createState() => _PlatformSettingsPageState();
}

class _PlatformSettingsPageState extends ConsumerState<PlatformSettingsPage> {
  late final _PlatformSettingsApi _api;
  late Future<List<_PlatformSettingsHistoryEntry>> _historyFuture;
  final _gstinController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _invoiceSequenceController = TextEditingController();

  _PlatformSettingsSnapshot? _snapshot;
  bool _loading = true;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _api = _PlatformSettingsApi(ref.read(apiClientProvider).dio);
    _historyFuture = _api.fetchHistory();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _gstinController.dispose();
    _businessNameController.dispose();
    _addressController.dispose();
    _invoiceSequenceController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final snapshot = await _api.fetchSnapshot();
      if (!mounted) {
        return;
      }

      if (!_controllersInitialized) {
        _applySnapshotToControllers(snapshot);
        _controllersInitialized = true;
      }

      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showMessage('Unable to load platform settings: $error');
    }
  }

  void _applySnapshotToControllers(_PlatformSettingsSnapshot snapshot) {
    _gstinController.text = snapshot.platformConfig.gstin ?? '';
    _businessNameController.text = snapshot.platformConfig.legalBusinessName ?? '';
    _addressController.text = snapshot.platformConfig.registeredAddress ?? '';
    _invoiceSequenceController.text = snapshot.invoiceSequence.currentValue.toString();
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _savePlatformSettings() async {
    final parsedInvoiceSequence = int.tryParse(_invoiceSequenceController.text.trim());

    try {
      final snapshot = await _api.updatePlatformSettings(
        gstin: _gstinController.text.trim(),
        legalBusinessName: _businessNameController.text.trim(),
        registeredAddress: _addressController.text.trim(),
        invoiceSequenceCurrentValue: parsedInvoiceSequence,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _controllersInitialized = true;
      });
      _applySnapshotToControllers(snapshot);
      await _showMessage('Platform settings saved');
    } catch (error) {
      await _showMessage('Unable to save platform settings: $error');
    }
  }

  Future<void> _refresh() async {
    _controllersInitialized = false;
    _historyFuture = _api.fetchHistory();
    await _loadSnapshot();
  }

  Future<void> _editCommission([_CommissionEntry? existing]) async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }

    final payload = await _showCommissionEditor(snapshot, existing: existing);
    if (payload == null) {
      return;
    }

    try {
      if (existing == null) {
        await _api.createCommission(payload);
      } else {
        await _api.updateCommission(existing.id, payload);
      }
      await _refresh();
      await _showMessage(existing == null ? 'Commission rule created' : 'Commission rule updated');
    } catch (error) {
      await _showMessage('Unable to save commission rule: $error');
    }
  }

  Future<void> _deleteCommission(_CommissionEntry commission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete commission rule?'),
          content: Text(
            commission.cityName == null
                ? 'Remove the global default commission rule?'
                : 'Remove the commission rule for ${commission.cityName}?',
          ),
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
      await _api.deleteCommission(commission.id);
      await _refresh();
      await _showMessage('Commission rule deleted');
    } catch (error) {
      await _showMessage('Unable to delete commission rule: $error');
    }
  }

  Future<Map<String, dynamic>?> _showCommissionEditor(
    _PlatformSettingsSnapshot snapshot, {
    _CommissionEntry? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final rateController = TextEditingController(text: existing?.rate.toStringAsFixed(2) ?? '18.00');
    final feeController = TextEditingController(text: existing?.fixedFee.toStringAsFixed(2) ?? '0.00');
    final cityValue = ValueNotifier<String>(existing?.cityId ?? _globalCommissionValue);
    final isActive = ValueNotifier<bool>(existing?.isActive ?? true);

    try {
      return await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(existing == null ? 'Add commission rule' : 'Edit commission rule'),
            content: SizedBox(
              width: 560,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: cityValue.value,
                            decoration: const InputDecoration(
                              labelText: 'Scope',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: _globalCommissionValue,
                                child: Text('Global default'),
                              ),
                              ...snapshot.cities.map(
                                (city) => DropdownMenuItem<String>(
                                  value: city.id,
                                  child: Text('${city.name} (${city.state})'),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => cityValue.value = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Commission rate %',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid commission rate';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: feeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Fixed fee',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = double.tryParse(value?.trim() ?? '');
                              if (parsed == null || parsed < 0) {
                                return 'Enter a valid fixed fee';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: isActive.value,
                            onChanged: (value) => setState(() => isActive.value = value),
                            title: const Text('Active'),
                            subtitle: const Text('Inactive rules stay in history but are ignored.'),
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
                  final rate = double.tryParse(rateController.text.trim());
                  final fixedFee = double.tryParse(feeController.text.trim());

                  if (rate == null || rate < 0 || fixedFee == null || fixedFee < 0) {
                    return;
                  }

                  Navigator.of(dialogContext).pop({
                    'cityId': cityValue.value == _globalCommissionValue ? null : cityValue.value,
                    'rate': rate,
                    'fixedFee': fixedFee,
                    'isActive': isActive.value,
                  });
                },
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      );
    } finally {
      rateController.dispose();
      feeController.dispose();
      cityValue.dispose();
      isActive.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final cs = Theme.of(context).colorScheme;

    final globalCommission = snapshot?.commissions.where((item) => item.cityId == null).toList(growable: false) ?? const <_CommissionEntry>[];
    final cityCommissions = snapshot?.commissions.where((item) => item.cityId != null).toList(growable: false) ?? const <_CommissionEntry>[];

    return AdminPageShell(
      title: 'Platform Settings',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSurfacePanel(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GST, invoices, and commissions',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: kAdminInk,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Manage the business identity used on invoices and the commission rules applied to settlements.',
                      style: TextStyle(
                        color: kAdminMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading && snapshot == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (snapshot != null) ...[
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    label: 'Cities',
                    value: '${snapshot.cities.length}',
                    icon: Icons.location_city_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  _MetricCard(
                    label: 'Commission rules',
                    value: '${snapshot.commissions.length}',
                    icon: Icons.percent_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                  _MetricCard(
                    label: 'Invoice sequence',
                    value: '#${snapshot.invoiceSequence.currentValue}',
                    icon: Icons.confirmation_number_rounded,
                    color: const Color(0xFF0F766E),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminSurfacePanel(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Business identity',
                        subtitle: 'These fields are printed on customer invoices and legal documents.',
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 900;
                          final fields = [
                            Expanded(
                              child: TextField(
                                controller: _gstinController,
                                decoration: const InputDecoration(
                                  labelText: 'GSTIN',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16, height: 16),
                            Expanded(
                              child: TextField(
                                controller: _businessNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Legal business name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ];

                          return Column(
                            children: [
                              compact
                                  ? Column(
                                      children: [
                                        TextField(
                                          controller: _gstinController,
                                          decoration: const InputDecoration(
                                            labelText: 'GSTIN',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: _businessNameController,
                                          decoration: const InputDecoration(
                                            labelText: 'Legal business name',
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(children: fields),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _addressController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Registered address',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _invoiceSequenceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Invoice sequence current value',
                                  helperText: 'The next generated invoice number increments from this value.',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _savePlatformSettings,
                                  icon: const Icon(Icons.save_rounded),
                                  label: const Text('Save platform settings'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AdminSurfacePanel(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: AdminSectionHeader(
                              title: 'Commission rules',
                              subtitle: 'Maintain a global default and city-specific overrides.',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _editCommission(null),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add rule'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (globalCommission.isNotEmpty)
                        _CommissionCard(
                          entry: globalCommission.first,
                          onEdit: () => _editCommission(globalCommission.first),
                          onDelete: () => _deleteCommission(globalCommission.first),
                          onTap: () => context.push('/platform-settings/commissions/${globalCommission.first.id}'),
                          isGlobal: true,
                        )
                      else
                        _EmptyCommissionCard(
                          title: 'No global default yet',
                          subtitle: 'Create a fallback commission rule for the whole platform.',
                          actionLabel: 'Add global rule',
                          onAction: () => _editCommission(null),
                        ),
                      const SizedBox(height: 16),
                      if (cityCommissions.isNotEmpty)
                        ...cityCommissions.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CommissionCard(
                              entry: entry,
                              onEdit: () => _editCommission(entry),
                              onDelete: () => _deleteCommission(entry),
                              onTap: () => context.push('/platform-settings/commissions/${entry.id}'),
                            ),
                          ),
                        )
                      else
                        const _EmptyCommissionCard(
                          title: 'No city overrides yet',
                          subtitle: 'Add a city-specific commission rule when a market needs a different fee.',
                          actionLabel: 'Add city rule',
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            AdminSurfacePanel(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AdminSectionHeader(
                      title: 'Recent changes',
                      subtitle: 'Latest platform setting and commission edits from the audit trail.',
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<_PlatformSettingsHistoryEntry>>(
                      future: _historyFuture,
                      builder: (context, historySnapshot) {
                        if (historySnapshot.connectionState == ConnectionState.waiting && !historySnapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (historySnapshot.hasError) {
                          return Text('Unable to load history: ${historySnapshot.error}');
                        }

                        final history = historySnapshot.data ?? const <_PlatformSettingsHistoryEntry>[];
                        if (history.isEmpty) {
                          return const Text('No recent changes found.');
                        }

                        return Column(
                          children: history
                              .take(6)
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _PlatformSettingsHistoryRow(entry: entry),
                                ),
                              )
                              .toList(growable: false),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AdminSurfacePanel(
              child: Padding(
                padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AdminSectionHeader(
                        title: 'Market coverage',
                        subtitle: 'Cities currently available for service-area and commission setup.',
                      ),
                    const SizedBox(height: 16),
                    if (snapshot == null || snapshot.cities.isEmpty)
                      const Text('No cities found.')
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: snapshot.cities
                            .map(
                              (city) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                                ),
                                child: Text('${city.name} · ${city.state}'),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformSettingsApi {
  _PlatformSettingsApi(this._dio);

  final Dio _dio;

  Future<_PlatformSettingsSnapshot> fetchSnapshot() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/platform-settings');
    return _PlatformSettingsSnapshot.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<List<_PlatformSettingsHistoryEntry>> fetchHistory() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/platform-settings/history');
    return (response.data?['history'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_PlatformSettingsHistoryEntry.fromJson)
        .toList(growable: false);
  }

  Future<_PlatformSettingsSnapshot> updatePlatformSettings({
    required String gstin,
    required String legalBusinessName,
    required String registeredAddress,
    int? invoiceSequenceCurrentValue,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/admin/platform-settings',
      data: {
        'gstin': gstin,
        'legalBusinessName': legalBusinessName,
        'registeredAddress': registeredAddress,
        if (invoiceSequenceCurrentValue != null) 'invoiceSequenceCurrentValue': invoiceSequenceCurrentValue,
      },
    );
    return _PlatformSettingsSnapshot.fromJson(response.data ?? const <String, dynamic>{});
  }

  Future<_CommissionEntry> createCommission(Map<String, dynamic> data) async {
    final response = await _dio.post<Map<String, dynamic>>('/admin/platform-settings/commissions', data: data);
    return _CommissionEntry.fromJson((response.data?['commission'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<_CommissionEntry> updateCommission(String commissionId, Map<String, dynamic> data) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/admin/platform-settings/commissions/$commissionId',
      data: data,
    );
    return _CommissionEntry.fromJson((response.data?['commission'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  Future<void> deleteCommission(String commissionId) async {
    await _dio.delete('/admin/platform-settings/commissions/$commissionId', data: const {});
  }
}

class _PlatformSettingsSnapshot {
  const _PlatformSettingsSnapshot({
    required this.platformConfig,
    required this.invoiceSequence,
    required this.commissions,
    required this.cities,
  });

  final _PlatformConfig platformConfig;
  final _InvoiceSequence invoiceSequence;
  final List<_CommissionEntry> commissions;
  final List<_CityOption> cities;

  factory _PlatformSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    return _PlatformSettingsSnapshot(
      platformConfig: _PlatformConfig.fromJson((json['platformConfig'] as Map?)?.cast<String, dynamic>() ?? const {}),
      invoiceSequence: _InvoiceSequence.fromJson((json['invoiceSequence'] as Map?)?.cast<String, dynamic>() ?? const {}),
      commissions: (json['commissions'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_CommissionEntry.fromJson)
          .toList(growable: false),
      cities: (json['cities'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_CityOption.fromJson)
          .toList(growable: false),
    );
  }
}

class _PlatformConfig {
  const _PlatformConfig({
    required this.gstin,
    required this.legalBusinessName,
    required this.registeredAddress,
  });

  final String? gstin;
  final String? legalBusinessName;
  final String? registeredAddress;

  factory _PlatformConfig.fromJson(Map<String, dynamic> json) {
    return _PlatformConfig(
      gstin: json['gstin'] as String?,
      legalBusinessName: json['legalBusinessName'] as String?,
      registeredAddress: json['registeredAddress'] as String?,
    );
  }
}

class _InvoiceSequence {
  const _InvoiceSequence({
    required this.currentValue,
  });

  final int currentValue;

  factory _InvoiceSequence.fromJson(Map<String, dynamic> json) {
    return _InvoiceSequence(
      currentValue: (json['currentValue'] as num?)?.toInt() ?? 0,
    );
  }
}

class _CommissionEntry {
  const _CommissionEntry({
    required this.id,
    required this.cityId,
    required this.cityName,
    required this.citySlug,
    required this.rate,
    required this.fixedFee,
    required this.isActive,
  });

  final String id;
  final String? cityId;
  final String? cityName;
  final String? citySlug;
  final double rate;
  final double fixedFee;
  final bool isActive;

  bool get isGlobal => cityId == null;

  factory _CommissionEntry.fromJson(Map<String, dynamic> json) {
    return _CommissionEntry(
      id: json['id'] as String? ?? '',
      cityId: json['cityId'] as String?,
      cityName: json['cityName'] as String?,
      citySlug: json['citySlug'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
      fixedFee: (json['fixedFee'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class _CityOption {
  const _CityOption({
    required this.id,
    required this.name,
    required this.slug,
    required this.state,
    required this.isActive,
  });

  final String id;
  final String name;
  final String slug;
  final String state;
  final bool isActive;

  factory _CityOption.fromJson(Map<String, dynamic> json) {
    return _CityOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      state: json['state'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class _PlatformSettingsHistoryEntry {
  const _PlatformSettingsHistoryEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.note,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String adminId;
  final String action;
  final String targetType;
  final String targetId;
  final String? note;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory _PlatformSettingsHistoryEntry.fromJson(Map<String, dynamic> json) {
    return _PlatformSettingsHistoryEntry(
      id: json['id'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      action: json['action'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      note: json['note'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
    return SizedBox(
      width: 240,
      child: AdminSurfacePanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                  Text(label, style: GoogleFonts.inter(fontSize: 12, color: kAdminMuted)),
                  Text(value, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformSettingsHistoryRow extends StatelessWidget {
  const _PlatformSettingsHistoryRow({required this.entry});

  final _PlatformSettingsHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history_rounded, color: Color(0xFF0F766E), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_readableAction(entry.action), style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  entry.note ?? entry.targetId,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM y, h:mm a').format(entry.createdAt)} · ${entry.adminId}',
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _readableAction(String action) {
  switch (action) {
    case 'platform.settings_updated':
      return 'Platform settings updated';
    case 'commission.created':
      return 'Commission rule created';
    case 'commission.updated':
      return 'Commission rule updated';
    case 'commission.deleted':
      return 'Commission rule deleted';
    default:
      return action.replaceAll('.', ' ');
  }
}

class _CommissionCard extends StatelessWidget {
  const _CommissionCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
    this.isGlobal = false,
  });

  final _CommissionEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool isGlobal;

  @override
  Widget build(BuildContext context) {
    final title = isGlobal ? 'Global default' : (entry.cityName ?? 'City rule');
    final subtitle = isGlobal
        ? 'Used when no city-specific rule matches.'
        : '${entry.cityName ?? ''}${entry.citySlug != null ? ' · ${entry.citySlug}' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAdminBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.percent_rounded, color: Color(0xFF0F766E)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (!entry.isActive)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: _TinyBadge(label: 'Inactive'),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$subtitle · ${entry.rate.toStringAsFixed(2)}% + Rs ${entry.fixedFee.toStringAsFixed(2)}',
            ),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommissionDetailPage extends ConsumerStatefulWidget {
  const CommissionDetailPage({
    super.key,
    required this.commissionId,
  });

  final String commissionId;

  @override
  ConsumerState<CommissionDetailPage> createState() => _CommissionDetailPageState();
}

class _CommissionDetailPageState extends ConsumerState<CommissionDetailPage> {
  late final _PlatformSettingsApi _api;
  late Future<({ _PlatformSettingsSnapshot snapshot, _CommissionEntry commission })?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = _PlatformSettingsApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<({ _PlatformSettingsSnapshot snapshot, _CommissionEntry commission })?> _load() async {
    final snapshot = await _api.fetchSnapshot();
    for (final commission in snapshot.commissions) {
      if (commission.id == widget.commissionId) {
        return (snapshot: snapshot, commission: commission);
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

  Future<void> _toggleActive(_CommissionEntry commission, _PlatformSettingsSnapshot snapshot) async {
    setState(() => _busy = true);
    try {
      await _api.updateCommission(
        commission.id,
        {
          'cityId': commission.cityId,
          'rate': commission.rate,
          'fixedFee': commission.fixedFee,
          'isActive': !commission.isActive,
        },
      );
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteCommission(_CommissionEntry commission) async {
    setState(() => _busy = true);
    try {
      await _api.deleteCommission(commission.id);
      if (!mounted) {
        return;
      }
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Commission Rule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<({ _PlatformSettingsSnapshot snapshot, _CommissionEntry commission })?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load commission rule: ${snapshot.error}'));
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
                    Text('Commission rule not found', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      'This commission rule is not present in the current platform snapshot.',
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

          final commission = data.commission;
          final snapshotData = data.snapshot;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.percent_rounded, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commission.isGlobal ? 'Global default' : (commission.cityName ?? 'City rule'),
                          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commission.isGlobal
                              ? 'Used when no city-specific rule matches.'
                              : '${commission.cityName ?? 'City'}${commission.citySlug != null ? ' · ${commission.citySlug}' : ''}',
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (!commission.isActive)
                    const _TinyBadge(label: 'Inactive'),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailChip(label: commission.isGlobal ? 'Global' : 'City specific'),
                  _DetailChip(label: '${commission.rate.toStringAsFixed(2)}%'),
                  _DetailChip(label: 'Rs ${commission.fixedFee.toStringAsFixed(2)} fixed'),
                  _DetailChip(label: commission.isActive ? 'Active' : 'Inactive'),
                ],
              ),
              const SizedBox(height: 18),
              _DetailLine(label: 'Commission ID', value: commission.id),
              _DetailLine(label: 'City ID', value: commission.cityId ?? 'Global'),
              _DetailLine(label: 'City name', value: commission.cityName ?? 'Global default'),
              _DetailLine(label: 'City slug', value: commission.citySlug ?? 'None'),
              _DetailLine(label: 'Rate', value: '${commission.rate.toStringAsFixed(2)}%'),
              _DetailLine(label: 'Fixed fee', value: 'Rs ${commission.fixedFee.toStringAsFixed(2)}'),
              _DetailLine(label: 'Status', value: commission.isActive ? 'Active' : 'Inactive'),
              _DetailLine(label: 'Available cities', value: '${snapshotData.cities.length}'),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : () => _toggleActive(commission, snapshotData),
                    child: Text(commission.isActive ? 'Disable rule' : 'Enable rule'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : () => _deleteCommission(commission),
                    style: OutlinedButton.styleFrom(foregroundColor: cs.error),
                    child: const Text('Delete rule'),
                  ),
                  OutlinedButton(
                    onPressed: _reload,
                    child: const Text('Refresh'),
                  ),
                ],
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFEF4444),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyCommissionCard extends StatelessWidget {
  const _EmptyCommissionCard({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

const String _globalCommissionValue = '__global__';
