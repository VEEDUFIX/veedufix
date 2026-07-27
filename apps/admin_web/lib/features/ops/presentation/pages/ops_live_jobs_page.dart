import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/ops_api.dart';

class OpsLiveJobsPage extends ConsumerStatefulWidget {
  const OpsLiveJobsPage({super.key});

  @override
  ConsumerState<OpsLiveJobsPage> createState() => _OpsLiveJobsPageState();
}

class _OpsLiveJobsPageState extends ConsumerState<OpsLiveJobsPage> {
  late final OpsApi _api;
  late Future<OpsOverviewSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _api.fetchOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _snapshotFuture = _api.fetchOverview();
    });
    await _snapshotFuture;
  }

  Future<void> _showJobDetails(OpsLiveJob job) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final rawEvidence = {
          'bookingId': job.bookingId,
          'bookingCode': job.bookingCode,
          'customerName': job.customerName,
          'workerName': job.workerName,
          'cityName': job.cityName,
          'serviceCategories': job.serviceCategories,
          'status': job.status,
          'scheduledAt': job.scheduledAt.toIso8601String(),
          'assignedAt': job.assignedAt.toIso8601String(),
          'beforePhotos': job.beforePhotos,
          'afterPhotos': job.afterPhotos,
          'checklistItems': job.checklistItems
              .map((item) => {'label': item.label, 'complete': item.complete})
              .toList(growable: false),
        };
        final encoder = const JsonEncoder.withIndent('  ');

        return AlertDialog(
          title: Text('${job.bookingCode} - ${job.customerName}'),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailChip(label: job.statusLabel),
                      _DetailChip(label: job.cityName),
                      _DetailChip(label: job.serviceLabel),
                      _DetailChip(label: '${job.elapsedLabel} active'),
                      _DetailChip(
                        label:
                            job.isNoShowRisk ? 'No-show risk' : 'Within window',
                        accent: job.isNoShowRisk
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailLine(
                      label: 'Worker', value: job.workerName ?? 'Unassigned'),
                  _DetailLine(
                      label: 'Scheduled',
                      value: _formatDate(context, job.scheduledAt)),
                  _DetailLine(
                      label: 'Assigned at',
                      value: _formatDate(context, job.assignedAt)),
                  _DetailLine(
                      label: 'Booking status',
                      value: job.bookingStatus.replaceAll('_', ' ')),
                  if ((job.notes ?? '').trim().isNotEmpty)
                    _DetailLine(label: 'Notes', value: job.notes!.trim()),
                  if ((job.customerNotes ?? '').trim().isNotEmpty)
                    _DetailLine(
                        label: 'Customer notes',
                        value: job.customerNotes!.trim()),
                  const SizedBox(height: 12),
                  Text(
                    'Before photos',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _PhotoStrip(urls: job.beforePhotos),
                  const SizedBox(height: 12),
                  Text(
                    'After photos',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  _PhotoStrip(urls: job.afterPhotos),
                  const SizedBox(height: 12),
                  Text(
                    'Checklist',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  if (job.checklistItems.isEmpty)
                    const Text('No checklist state stored yet.')
                  else
                    ...job.checklistItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              item.complete
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: item.complete
                                  ? const Color(0xFF0F766E)
                                  : Theme.of(context).colorScheme.outline,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(item.label)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Raw evidence snapshot',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    encoder.convert(rawEvidence),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Live jobs',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<OpsOverviewSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load live jobs',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final jobs = snapshot.data?.liveJobs ?? const <OpsLiveJob>[];

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _SurfacePanel(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active jobs right now',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF13110F),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track bookings currently assigned, arrived, or in progress. Highlighted rows are at risk of a no-show timeout.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B6256),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _SummaryBadge(
                                  label: 'Assigned',
                                  value:
                                      '${jobs.where((job) => job.status == 'assigned').length}'),
                              _SummaryBadge(
                                  label: 'Arrived',
                                  value:
                                      '${jobs.where((job) => job.status == 'arrived').length}'),
                              _SummaryBadge(
                                  label: 'In progress',
                                  value:
                                      '${jobs.where((job) => job.status == 'in_progress').length}'),
                              _SummaryBadge(
                                  label: 'No-show risk',
                                  value:
                                      '${jobs.where((job) => job.isNoShowRisk).length}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (jobs.isEmpty)
                    const _SurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PremiumEmptyState(
                          icon: Icons.work_off_rounded,
                          title: 'No active jobs',
                          subtitle:
                              'Accepted jobs will appear here once workers move them into active states.',
                        ),
                      ),
                    )
                  else
                    _SurfacePanel(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                              const WidgetStatePropertyAll(Color(0xFFF7F1E4)),
                          columns: const [
                            DataColumn(label: Text('Booking')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('Worker')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Elapsed')),
                            DataColumn(label: Text('Scheduled')),
                          ],
                          rows: jobs
                              .map(
                                (job) => DataRow(
                                  color:
                                      WidgetStateProperty.resolveWith<Color?>(
                                    (states) {
                                      if (job.isNoShowRisk) {
                                        return const Color(0xFFEF4444)
                                            .withValues(alpha: 0.08);
                                      }
                                      return null;
                                    },
                                  ),
                                  cells: [
                                    DataCell(Text(job.bookingCode)),
                                    DataCell(Text(job.customerName)),
                                    DataCell(
                                        Text(job.workerName ?? 'Unassigned')),
                                    DataCell(SizedBox(
                                        width: 180,
                                        child: Text(job.serviceLabel))),
                                    DataCell(_StatusPill(status: job.status)),
                                    DataCell(Text(job.elapsedLabel)),
                                    DataCell(Text(
                                        _formatDate(context, job.scheduledAt))),
                                  ],
                                  onSelectChanged: (_) => _showJobDetails(job),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'arrived' => const Color(0xFF0F766E),
      'in_progress' => const Color(0xFF2563EB),
      _ => const Color(0xFFF59E0B),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const Text('No photos uploaded.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: urls
          .map(
            (url) => ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                url,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 120,
                  height: 120,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.label,
    this.accent,
  });

  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

String _formatDate(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatMediumDate(value);
}

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5D8C6)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            color: const Color(0xFF13110F),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5D8C6)),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: child,
    );
  }
}
