import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../features/checkout/presentation/pages/checkout_page.dart';
import '../../../../features/profile/data/saved_addresses_api.dart';

final customerMaintenancePlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final response = await api.get('/maintenance-plans');
      final data = response as Map<dynamic, dynamic>;
      final rows = data['plans'];
      return rows is List
          ? rows
                .whereType<Map>()
                .map((row) => row.cast<String, dynamic>())
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
    });

final maintenanceAddressesProvider =
    FutureProvider.autoDispose<List<SavedAddressItem>>((ref) async {
      final api = ref.watch(apiClientProvider);
      return SavedAddressesApi(api.dio).listAddresses();
    });

class MaintenancePlansPage extends ConsumerWidget {
  const MaintenancePlansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(customerMaintenancePlansProvider);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Maintenance plans')),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Plans could not load',
          message: 'Check your connection and try again.',
          action: TextButton(
            onPressed: () => ref.invalidate(customerMaintenancePlansProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const _MessageState(
                icon: Icons.event_repeat_outlined,
                title: 'No maintenance plans yet',
                message:
                    'Choose an eligible service and set a frequency. You will confirm each visit before checkout.',
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(customerMaintenancePlansProvider.future),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _MaintenancePlanCard(plan: items[index]),
                ),
              ),
      ),
    );
  }
}

class _MaintenancePlanCard extends ConsumerStatefulWidget {
  const _MaintenancePlanCard({required this.plan});
  final Map<String, dynamic> plan;

  @override
  ConsumerState<_MaintenancePlanCard> createState() =>
      _MaintenancePlanCardState();
}

class _MaintenancePlanCardState extends ConsumerState<_MaintenancePlanCard> {
  bool _actionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final colors = Theme.of(context).colorScheme;
    final service =
        (plan['service'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final variant = (plan['variant'] as Map?)?.cast<String, dynamic>();
    final address =
        (plan['address'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final occurrences = (plan['occurrences'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    final prioritizedOccurrences = [...occurrences]
      ..sort((a, b) {
        const actionableStatuses = {'AWAITING_CONFIRMATION', 'BOOKING_CREATED'};
        final aActionable = actionableStatuses.contains(a['status']);
        final bActionable = actionableStatuses.contains(b['status']);
        if (aActionable != bActionable) return aActionable ? -1 : 1;

        final aDue = DateTime.tryParse(a['dueAt'] as String? ?? '');
        final bDue = DateTime.tryParse(b['dueAt'] as String? ?? '');
        if (aDue == null || bDue == null) {
          if (aDue == null && bDue != null) return 1;
          if (aDue != null && bDue == null) return -1;
          return 0;
        }
        return bDue.compareTo(aDue);
      });
    final status = (plan['status'] as String? ?? 'ACTIVE').toLowerCase();
    final interval = (plan['intervalMonths'] as num?)?.toInt() ?? 0;
    final due = _parsePlanDate(plan['nextDueAt'] as String?);
    return VeeduFixCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${service['name'] as String? ?? 'Maintenance service'}${variant == null ? '' : ' · ${variant['name']}'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusLabel(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            interval == 1 ? 'Every month' : 'Every $interval months',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if ((address['label'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              '${address['label']} · ${address['pincode'] ?? ''}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          if (due != null && status == 'active') ...[
            const SizedBox(height: 8),
            Text(
              'Next plan date · ${_formatDate(due)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'This is a plan date, not a confirmed appointment. Confirm and pay through checkout for each visit.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          for (final occurrence in prioritizedOccurrences.take(3))
            _OccurrenceRow(plan: plan, occurrence: occurrence),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (status == 'active')
                OutlinedButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _changePlan(context, ref, 'pause'),
                  child: const Text('Pause'),
                ),
              if (status == 'paused')
                OutlinedButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _changePlan(context, ref, 'resume'),
                  child: const Text('Resume'),
                ),
              if (status != 'cancelled')
                TextButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _confirmCancel(context, ref),
                  child: const Text('Cancel plan'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changePlan(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await ref
          .read(apiClientProvider)
          .post('/maintenance-plans/${widget.plan['id']}/$action');
      if (!mounted) return;
      ref.invalidate(customerMaintenancePlansProvider);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not update the plan. Try again.');
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel maintenance plan?'),
          content: const Text(
            'Future plan reminders and visits will stop. Existing bookings are not cancelled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep plan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel plan'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await ref
            .read(apiClientProvider)
            .post('/maintenance-plans/${widget.plan['id']}/cancel');
        if (!mounted || !context.mounted) return;
        ref.invalidate(customerMaintenancePlansProvider);
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not update the plan. Try again.');
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }
}

class _OccurrenceRow extends ConsumerStatefulWidget {
  const _OccurrenceRow({required this.plan, required this.occurrence});
  final Map<String, dynamic> plan;
  final Map<String, dynamic> occurrence;

  @override
  ConsumerState<_OccurrenceRow> createState() => _OccurrenceRowState();
}

class _OccurrenceRowState extends ConsumerState<_OccurrenceRow> {
  bool _actionInProgress = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final occurrence = widget.occurrence;
    final colors = Theme.of(context).colorScheme;
    final due = _parsePlanDate(occurrence['dueAt'] as String?);
    // Maintenance plans are scheduled in Asia/Kolkata. Compare calendar dates
    // in that market timezone, independent of the device timezone or DST.
    final today = _todayInPlanTimezone();
    final dueDay = due == null
        ? null
        : DateTime.utc(due.year, due.month, due.day);
    final withinCheckoutWindow =
        dueDay != null &&
        !dueDay.isBefore(today) &&
        dueDay.difference(today).inDays <= 6;
    final status = occurrence['status'] as String? ?? 'AWAITING_CONFIRMATION';
    final booking = (occurrence['booking'] as Map?)?.cast<String, dynamic>();
    final service =
        (plan['service'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final variant = (plan['variant'] as Map?)?.cast<String, dynamic>();
    final address =
        (plan['address'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${due == null ? 'Upcoming visit' : _formatDate(due)} · ${_humanStatus(status, booking?['status'] as String?)}',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (booking != null)
            Text(
              'Booking ${booking['code'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (status == 'AWAITING_CONFIRMATION' || status == 'FAILED') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: !withinCheckoutWindow
                      ? null
                      : () => context.push(
                          '/checkout',
                          extra: {
                            'cityId':
                                ref
                                    .read(authControllerProvider)
                                    .valueOrNull
                                    ?.user
                                    .cityId ??
                                '',
                            'items': [
                              CheckoutItem(
                                serviceId: service['id'] as String? ?? '',
                                serviceName:
                                    '${service['name'] as String? ?? 'Service'}${variant == null ? '' : ' · ${variant['name']}'}',
                                price:
                                    (variant?['price'] as num?)?.toDouble() ??
                                    (service['startingPrice'] as num?)
                                        ?.toDouble() ??
                                    0,
                                variantId: variant?['id'] as String?,
                              ),
                            ],
                            'maintenanceOccurrenceId': occurrence['id']
                                ?.toString(),
                            'maintenanceDueAt': due,
                            'preferredAddressId': address['id']?.toString(),
                            'maintenancePreferredTime': plan['preferredTime']
                                ?.toString(),
                          },
                        ),
                  child: const Text('Choose time & confirm'),
                ),
                TextButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _skip(context, ref),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: _actionInProgress
                      ? null
                      : () => _reschedule(context, ref, due),
                  child: const Text('Reschedule'),
                ),
              ],
            ),
            if (!withinCheckoutWindow) ...[
              const SizedBox(height: 6),
              Text(
                dueDay == null
                    ? 'Booking opens when the scheduled visit is closer.'
                    : dueDay.isBefore(today)
                    ? 'This visit date has passed. Reschedule it to choose a new time.'
                    : 'Booking opens on ${_formatDate(dueDay.subtract(const Duration(days: 6)))}.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/maintenance-plans/${widget.plan['id']}/occurrences/${widget.occurrence['id']}/skip',
          );
      if (!mounted) return;
      ref.invalidate(customerMaintenancePlansProvider);
    } catch (_) {
      if (context.mounted) _showError(context, 'Could not skip this visit.');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    if (_actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final today = _todayInPlanTimezone();
      final firstDate = today.add(const Duration(days: 1));
      final lastDate = today.add(const Duration(days: 365));
      final currentDate = current == null
          ? firstDate
          : DateTime.utc(current.year, current.month, current.day);
      final selected = await showDatePicker(
        context: context,
        initialDate: currentDate.isBefore(firstDate)
            ? firstDate
            : currentDate.isAfter(lastDate)
            ? lastDate
            : currentDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (selected == null || !context.mounted) return;
      final dueAt =
          '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      await ref
          .read(apiClientProvider)
          .post(
            '/maintenance-plans/${widget.plan['id']}/occurrences/${widget.occurrence['id']}/reschedule',
            data: {'dueAt': dueAt},
          );
      if (!mounted || !context.mounted) return;
      ref.invalidate(customerMaintenancePlansProvider);
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not reschedule this visit.');
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }
}

class MaintenancePlanCreatePage extends ConsumerStatefulWidget {
  const MaintenancePlanCreatePage({super.key, required this.serviceId});
  final String serviceId;
  @override
  ConsumerState<MaintenancePlanCreatePage> createState() =>
      _MaintenancePlanCreatePageState();
}

class _MaintenancePlanCreatePageState
    extends ConsumerState<MaintenancePlanCreatePage> {
  String? _addressId;
  int? _intervalMonths;
  String? _variantId;
  DateTime _startDate = _todayInPlanTimezone().add(const Duration(days: 1));
  TimeOfDay? _preferredTime;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(serviceDetailProvider(widget.serviceId));
    final addresses = ref.watch(maintenanceAddressesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Set up maintenance')),
      body: service.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _MessageState(
          icon: Icons.cloud_off_outlined,
          title: 'Service unavailable',
          message: 'Try again later.',
          action: TextButton(
            onPressed: () =>
                ref.invalidate(serviceDetailProvider(widget.serviceId)),
            child: const Text('Retry'),
          ),
        ),
        data: (item) {
          final frequencies = item.maintenanceIntervalsMonths;
          final options = item.variants;
          if (!item.maintenanceEnabled || frequencies.isEmpty) {
            return const _MessageState(
              icon: Icons.event_busy_outlined,
              title: 'Maintenance plans unavailable',
              message:
                  'This service is not configured for recurring maintenance.',
            );
          }
          if (!frequencies.contains(_intervalMonths)) {
            _intervalMonths = frequencies.first;
          }
          return addresses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _MessageState(
              icon: Icons.location_off_outlined,
              title: 'Addresses unavailable',
              message: 'Check your connection and try again.',
              action: TextButton(
                onPressed: () => ref.invalidate(maintenanceAddressesProvider),
                child: const Text('Retry'),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _MessageState(
                  icon: Icons.location_off_outlined,
                  title: 'Add a service address',
                  message:
                      'Save an address before creating a maintenance plan.',
                );
              }
              if (!items.any((address) => address.id == _addressId)) {
                _addressId = items
                    .firstWhere(
                      (address) => address.isDefault,
                      orElse: () => items.first,
                    )
                    .id;
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  VeeduFixCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estimated current starting price · ₹${item.startingPrice.toStringAsFixed(0)} per visit',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The price and availability are checked again for every visit. No automatic booking or charge is created.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (options.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue:
                          options.any((option) => option.id == _variantId)
                          ? _variantId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Service option',
                      ),
                      items: options
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.id,
                              child: Text(
                                '${option.name} · ₹${option.price.toStringAsFixed(0)}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _variantId = value),
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    key: ValueKey(_addressId),
                    initialValue:
                        items.any((address) => address.id == _addressId)
                        ? _addressId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Service address',
                    ),
                    items: items
                        .map(
                          (address) => DropdownMenuItem(
                            value: address.id,
                            child: Text(
                              '${address.label} · ${address.pincode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _addressId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: frequencies.contains(_intervalMonths)
                        ? _intervalMonths
                        : frequencies.first,
                    decoration: const InputDecoration(
                      labelText: 'Maintenance frequency',
                    ),
                    items: frequencies
                        .map(
                          (months) => DropdownMenuItem(
                            value: months,
                            child: Text(
                              months == 1
                                  ? 'Monthly'
                                  : months == 3
                                  ? 'Quarterly'
                                  : 'Every $months months',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _intervalMonths = value),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('First plan date'),
                    subtitle: Text(_formatDate(_startDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final planToday = _todayInPlanTimezone();
                      final firstDate = DateTime(
                        planToday.year,
                        planToday.month,
                        planToday.day,
                      ).add(const Duration(days: 1));
                      final lastDate = firstDate.add(const Duration(days: 365));
                      final initialDate = DateTime(
                        _startDate.year,
                        _startDate.month,
                        _startDate.day,
                      );
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: initialDate.isBefore(firstDate)
                            ? firstDate
                            : initialDate.isAfter(lastDate)
                            ? lastDate
                            : initialDate,
                        firstDate: firstDate,
                        lastDate: lastDate,
                      );
                      if (selected != null && mounted) {
                        setState(() => _startDate = selected);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Preferred time (optional)'),
                    subtitle: Text(
                      _preferredTime?.format(context) ??
                          'Choose later for each visit',
                    ),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: () async {
                      final selected = await showTimePicker(
                        context: context,
                        initialTime:
                            _preferredTime ??
                            const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (selected != null && mounted) {
                        setState(() => _preferredTime = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  VeeduFixButton(
                    label: 'Create maintenance plan',
                    isLoading: _saving,
                    onPressed:
                        _saving ||
                            _addressId == null ||
                            (options.isNotEmpty && _variantId == null)
                        ? null
                        : () => _createPlan(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createPlan() async {
    setState(() => _saving = true);
    final date =
        '${_startDate.year.toString().padLeft(4, '0')}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}';
    try {
      await ref
          .read(apiClientProvider)
          .post(
            '/maintenance-plans',
            data: {
              'serviceId': widget.serviceId,
              if (_variantId != null) 'variantId': _variantId,
              'addressId': _addressId,
              'intervalMonths': _intervalMonths,
              'startAt': date,
              // Maintenance appointments are scheduled in the Chennai launch
              // market's local timezone, regardless of the Customer device.
              'timezone': 'Asia/Kolkata',
              if (_preferredTime != null)
                'preferredTime':
                    '${_preferredTime!.hour.toString().padLeft(2, '0')}:${_preferredTime!.minute.toString().padLeft(2, '0')}',
            },
          );
      if (!mounted) return;
      ref.invalidate(customerMaintenancePlansProvider);
      if (mounted) context.go('/maintenance-plans');
    } catch (_) {
      if (mounted) {
        _showError(
          context,
          'Could not create the plan. Check the service area and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? Colors.teal.shade700
        : status == 'paused'
        ? Colors.orange.shade800
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty
            ? 'Unknown'
            : status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null) action!,
        ],
      ),
    ),
  );
}

String _formatDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

DateTime? _parsePlanDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  return parsed?.toUtc().add(const Duration(hours: 5, minutes: 30));
}

DateTime _todayInPlanTimezone() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(now.year, now.month, now.day);
}

String _humanStatus(String status, String? bookingStatus) {
  if (status == 'BOOKING_CREATED') {
    return bookingStatus == null
        ? 'Booking pending'
        : 'Booking ${bookingStatus.toLowerCase().replaceAll('_', ' ')}';
  }
  return switch (status) {
    'AWAITING_CONFIRMATION' => 'Awaiting your confirmation',
    'SKIPPED' => 'Skipped',
    'FAILED' => 'Needs attention',
    'CANCELLED' => 'Cancelled',
    _ => status.toLowerCase(),
  };
}

void _showError(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
