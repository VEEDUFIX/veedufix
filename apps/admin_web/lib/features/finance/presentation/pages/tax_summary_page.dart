import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../admin/presentation/widgets/admin_surface.dart';
import '../../data/finance_api.dart';

class TaxSummaryPage extends ConsumerStatefulWidget {
  const TaxSummaryPage({super.key});

  @override
  ConsumerState<TaxSummaryPage> createState() => _TaxSummaryPageState();
}

class _TaxSummaryPageState extends ConsumerState<TaxSummaryPage> {
  late final FinanceApi _api;
  late DateTimeRange _selectedRange;
  String _selectedPreset = _TaxPreset.thisMonth;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  TaxGstSummary? _gstSummary;
  TaxRevenueSummary? _revenueSummary;
  TaxAnnualSummary? _annualSummary;

  @override
  void initState() {
    super.initState();
    _api = FinanceApi(ref.read(apiClientProvider).dio);
    _selectedRange = _presetRange(_selectedPreset);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _busy = false;
      _annualSummary = null;
    });

    try {
      if (_selectedPreset == _TaxPreset.financialYear) {
        final annual = await _api.fetchTaxAnnualSummary(_financialYearLabelForRange(_selectedRange));
        if (!mounted) {
          return;
        }
        setState(() {
          _annualSummary = annual;
          _gstSummary = annual.gstSummary;
          _revenueSummary = annual.revenueSummary;
          _loading = false;
        });
        return;
      }

      final results = await Future.wait([
        _api.fetchTaxGstSummary(
          startDate: _selectedRange.start,
          endDate: _selectedRange.end,
        ),
        _api.fetchTaxRevenueSummary(
          startDate: _selectedRange.start,
          endDate: _selectedRange.end,
        ),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _gstSummary = results[0] as TaxGstSummary;
        _revenueSummary = results[1] as TaxRevenueSummary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reload() async {
    await _load();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 4, 1),
      lastDate: DateTime(DateTime.now().year + 1, 3, 31),
      initialDateRange: _selectedRange,
      helpText: 'Select tax summary period',
    );

    if (range == null) {
      return;
    }

    setState(() {
      _selectedRange = DateTimeRange(
        start: DateTime(range.start.year, range.start.month, range.start.day),
        end: DateTime(range.end.year, range.end.month, range.end.day),
      );
      _selectedPreset = _TaxPreset.custom;
    });
    await _load();
  }

  Future<void> _applyPreset(String preset) async {
    setState(() {
      _selectedPreset = preset;
      _selectedRange = _presetRange(preset);
    });
    await _load();
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    try {
      final url = _api.taxSummaryCsvUrl(
        startDate: _selectedRange.start,
        endDate: _selectedRange.end,
      );
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open CSV download link')),
        );
      }
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
    final dateLabel = _formatRange(_selectedRange);
    final gstSummary = _gstSummary;
    final revenueSummary = _revenueSummary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Tax Summary'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            ),
          ],
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && gstSummary == null && revenueSummary == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && gstSummary == null && revenueSummary == null
              ? Center(
                  child: PremiumEmptyState(
                    icon: Icons.request_quote_rounded,
                    title: 'Tax summary unavailable',
                    subtitle: _error ?? 'Unknown error',
                    actionLabel: 'Try again',
                    onAction: _reload,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      const AdminSurfacePanel(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: _DisclaimerBanner(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AdminSurfacePanel(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tax summary dashboard',
                                style: tt.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: kAdminInk,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Review GST liability, platform commission, and worker payouts for GST filing preparation and ITR support.',
                                style: tt.bodyMedium?.copyWith(
                                  color: kAdminMuted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _RangeChip(
                                    label: 'This month',
                                    selected: _selectedPreset == _TaxPreset.thisMonth,
                                    onTap: () => _applyPreset(_TaxPreset.thisMonth),
                                  ),
                                  _RangeChip(
                                    label: 'This quarter',
                                    selected: _selectedPreset == _TaxPreset.thisQuarter,
                                    onTap: () => _applyPreset(_TaxPreset.thisQuarter),
                                  ),
                                  _RangeChip(
                                    label: 'Financial year',
                                    selected: _selectedPreset == _TaxPreset.financialYear,
                                    onTap: () => _applyPreset(_TaxPreset.financialYear),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickDateRange,
                                    icon: const Icon(Icons.date_range_rounded, size: 18),
                                    label: const Text('Custom range'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Period: $dateLabel',
                                style: tt.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_annualSummary != null) ...[
                        const SizedBox(height: 16),
                        AdminSurfacePanel(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF0F766E)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Annual window ${_annualSummary!.financialYear}',
                                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Period ${_annualSummary!.periodStart != null ? DateFormat('dd MMM yyyy').format(_annualSummary!.periodStart!.toLocal()) : ''} to ${_annualSummary!.periodEnd != null ? DateFormat('dd MMM yyyy').format(_annualSummary!.periodEnd!.toLocal()) : ''}',
                                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _SummaryCard(
                            title: 'GST summary',
                            accent: const Color(0xFF0F766E),
                            children: [
                              _MetricRow(label: 'Invoices', value: gstSummary?.invoiceCount.toString() ?? '0'),
                              _MetricRow(
                                label: 'Taxable value',
                                value: _formatCurrency(gstSummary?.totalTaxableValue ?? 0),
                              ),
                              _MetricRow(
                                label: 'GST collected',
                                value: _formatCurrency(gstSummary?.totalGstCollected ?? 0),
                              ),
                            ],
                          ),
                          _SummaryCard(
                            title: 'Revenue summary',
                            accent: const Color(0xFF2563EB),
                            children: [
                              _MetricRow(
                                label: 'Platform commission earned',
                                value: _formatCurrency(revenueSummary?.platformCommissionEarned ?? 0),
                              ),
                              _MetricRow(
                                label: 'GST liability',
                                value: _formatCurrency(revenueSummary?.totalGstLiability ?? 0),
                              ),
                              _MetricRow(
                                label: 'Worker payouts',
                                value: _formatCurrency(revenueSummary?.totalWorkerPayouts ?? 0),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AdminSurfacePanel(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_tree_rounded, color: Color(0xFF0F766E)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SAC breakdown',
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if ((gstSummary?.breakdown ?? const []).isEmpty)
                                Text(
                                  'No invoice line items found for the selected period.',
                                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                                )
                              else
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                        child: DataTable(
                                          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                                          headingTextStyle: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                            letterSpacing: 0.8,
                                          ),
                                          columns: const [
                                            DataColumn(label: Text('SAC CODE')),
                                            DataColumn(label: Text('INVOICES')),
                                            DataColumn(label: Text('TAXABLE VALUE')),
                                            DataColumn(label: Text('GST')),
                                          ],
                                          rows: (gstSummary?.breakdown ?? const [])
                                              .map(
                                                (item) => DataRow(
                                                  cells: [
                                                    DataCell(Text(item.sacCode)),
                                                    DataCell(Text(item.invoiceCount.toString())),
                                                    DataCell(Text(_formatCurrency(item.taxableValue))),
                                                    DataCell(Text(_formatCurrency(item.gstAmount))),
                                                  ],
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: tt.bodySmall?.copyWith(color: cs.error),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _TaxPreset {
  static const thisMonth = 'this_month';
  static const thisQuarter = 'this_quarter';
  static const financialYear = 'financial_year';
  static const custom = 'custom';
}

class _DisclaimerBanner extends StatelessWidget {
  const _DisclaimerBanner();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'This summary is for reference only. Please confirm all figures with your CA before filing GST returns or ITR.',
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFF0F766E);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: selectedColor.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? selectedColor : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? selectedColor : const Color(0xFFD1D5DB)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.accent,
    required this.children,
  });

  final String title;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: 420,
      child: AdminSurfacePanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.pie_chart_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: kAdminInk,
            ),
          ),
        ],
      ),
    );
  }
}

DateTimeRange _presetRange(String preset) {
  final now = DateTime.now();
  if (preset == _TaxPreset.thisQuarter) {
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final start = DateTime(now.year, quarterStartMonth, 1);
    final nextQuarter = quarterStartMonth + 3;
    final end = nextQuarter > 12 ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1)) : DateTime(now.year, nextQuarter, 1).subtract(const Duration(days: 1));
    return DateTimeRange(start: start, end: end);
  }

  if (preset == _TaxPreset.financialYear) {
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    final start = DateTime(fyStartYear, 4, 1);
    final end = DateTime(fyStartYear + 1, 3, 31);
    return DateTimeRange(start: start, end: end);
  }

  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0);
  return DateTimeRange(start: start, end: end);
}

String _financialYearLabelForRange(DateTimeRange range) {
  final startYear = range.start.month >= 4 ? range.start.year : range.start.year - 1;
  return '$startYear-${(startYear + 1).toString().substring(2)}';
}

String _formatRange(DateTimeRange range) {
  final formatter = DateFormat('dd MMM yyyy');
  return '${formatter.format(range.start)} to ${formatter.format(range.end)}';
}

String _formatCurrency(double value) {
  return NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2).format(value);
}
