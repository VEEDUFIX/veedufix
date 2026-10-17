import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

final _adminMaintenancePlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(apiClientProvider).get('/maintenance-plans/admin');
  final data = response as Map<dynamic, dynamic>;
  final plans = data['plans'];
  return plans is List
      ? plans
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList(growable: false)
      : const [];
});

String _maintenancePlansLoadError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Your Admin session expired. Sign in and retry.';
    if (status == 403) {
      return 'This account does not have access to maintenance plans.';
    }
    if (status != null) {
      return 'Maintenance plans could not load (HTTP $status).';
    }
    return 'Could not reach the backend. Check the connection and retry.';
  }
  final message =
      error.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
  final concise =
      message.length > 160 ? '${message.substring(0, 157)}…' : message;
  return concise.isEmpty
      ? 'Maintenance plans could not load.'
      : 'Maintenance plans could not load: $concise';
}

class MaintenancePlansAdminPage extends ConsumerWidget {
  const MaintenancePlansAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(_adminMaintenancePlansProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Maintenance plans'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_adminMaintenancePlansProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_maintenancePlansLoadError(error)),
          TextButton(
              onPressed: () => ref.invalidate(_adminMaintenancePlansProvider),
              child: const Text('Retry'))
        ])),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No recurring maintenance plans yet.'))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(_adminMaintenancePlansProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AdminPlanCard(plan: items[index]),
                )),
      ),
    );
  }
}

class _AdminPlanCard extends StatelessWidget {
  const _AdminPlanCard({required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context) {
    final service = (plan['service'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final customer = (plan['customer'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final address = (plan['address'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final occurrences = (plan['occurrences'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
    final events = (plan['events'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList();
    final interval = (plan['intervalMonths'] as num?)?.toInt() ?? 0;
    return VeeduFixCard(
        padding: const EdgeInsets.all(16),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
              '${service['name'] ?? 'Service'} · ${plan['status'] ?? ''}',
              style: Theme.of(context).textTheme.titleMedium),
          subtitle: Text(
              '${customer['name'] ?? 'Customer'} · every $interval month(s) · ${address['pincode'] ?? ''}'),
          children: [
            for (final occurrence in occurrences)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_note_outlined),
                title: Text(
                    '${_dateOnly(occurrence['dueAt'])} · ${occurrence['status'] ?? ''}'),
                subtitle: Text(_bookingSummary(occurrence['booking'])),
              ),
            if (events.isNotEmpty) ...[
              const Divider(),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Plan history',
                      style: Theme.of(context).textTheme.titleSmall)),
              for (final event in events.take(8))
                ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text((event['action'] as String? ?? '')
                        .replaceAll('_', ' ')
                        .toLowerCase()),
                    subtitle: Text(_date(event['createdAt']))),
            ],
          ],
        ));
  }

  String _bookingSummary(dynamic value) {
    if (value is! Map) return 'No booking created';
    final booking = value.cast<String, dynamic>();
    return 'Booking ${booking['code'] ?? ''} · ${booking['status'] ?? ''}';
  }

  String _date(dynamic value) =>
      DateTime.tryParse(value as String? ?? '')
          ?.toLocal()
          .toString()
          .split('.')
          .first ??
      'Date unavailable';

  String _dateOnly(dynamic value) {
    final date = DateTime.tryParse(value as String? ?? '')?.toUtc();
    if (date == null) return 'Date unavailable';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
