import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/analytics_api.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  late final AnalyticsApi _api;
  AnalyticsPayload? _payload;
  bool _isLoading = true;
  String? _error;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _api = AnalyticsApi(ref.read(apiClientProvider).dio);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final payload = await _api.fetchTrends(days: _days);
      if (mounted) {
        setState(() {
          _payload = payload;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analytics',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track bookings, worker supply, revenue, and support trends over the last 30 days.',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _RangeChip(
                  label: '7 days',
                  selected: _days == 7,
                  onTap: () {
                    setState(() => _days = 7);
                    _loadData();
                  },
                ),
                _RangeChip(
                  label: '30 days',
                  selected: _days == 30,
                  onTap: () {
                    setState(() => _days = 30);
                    _loadData();
                  },
                ),
                _RangeChip(
                  label: '90 days',
                  selected: _days == 90,
                  onTap: () {
                    setState(() => _days = 90);
                    _loadData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Center(
                child: Text('Failed to load data: $_error', style: const TextStyle(color: Colors.red)),
              )
            else if (_payload != null) ...[
            _AnalyticsSummaryRow(
              trends: _payload!.trends,
              activeBookings: _payload!.activeBookings,
            ),
              const SizedBox(height: 24),
              // Charts row 1 — GMV + Bookings
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRevenueChart(_payload!.trends)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildBookingsChart(_payload!.trends)),
                ],
              ),
              const SizedBox(height: 24),
              // Commission chart — full width
              _buildCommissionChart(_payload!.trends),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  final items = [
                    _BreakdownCard(title: 'Top cities', items: _payload!.insights.byCity),
                    _BreakdownCard(title: 'Top categories', items: _payload!.insights.byCategory),
                  ];

                  if (compact) {
                    return Column(
                      children: [
                        items[0],
                        const SizedBox(height: 16),
                        items[1],
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: items[0]),
                      const SizedBox(width: 24),
                      Expanded(child: items[1]),
                    ],
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionChart(List<DailyTrendPoint> trends) {
    if (trends.isEmpty) return const SizedBox();

    final maxY = trends
        .map((t) => t.commission)
        .fold<double>(0, (m, v) => v > m ? v : m);

    return _ChartCard(
      title: 'Commission Earned (₹)',
      subtitle: 'Platform revenue from completed jobs',
      fullWidth: true,
      chart: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? (maxY / 4) : 500,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Color(0xFFE5E7EB), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                interval: maxY > 0 ? (maxY / 4) : 500,
                getTitlesWidget: (value, _) => Text(
                  NumberFormat.compact().format(value),
                  style:
                      const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 7,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= trends.length) {
                    return const SizedBox();
                  }
                  final date = DateTime.parse(trends[index].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MMM d').format(date),
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trends.length - 1).toDouble(),
          minY: 0,
          maxY: maxY > 0 ? maxY * 1.2 : 1000,
          lineBarsData: [
            LineChartBarData(
              spots: trends
                  .asMap()
                  .entries
                  .map((e) =>
                      FlSpot(e.key.toDouble(), e.value.commission))
                  .toList(),
              isCurved: true,
              color: const Color(0xFF059669),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF059669).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<DailyTrendPoint> trends) {
    if (trends.isEmpty) return const SizedBox();

    final maxY = trends.map((t) => t.revenue).fold<double>(0, (m, v) => v > m ? v : m);
    
    return _ChartCard(
      title: 'Revenue Trend (₹)',
      chart: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? (maxY / 4) : 1000,
            getDrawingHorizontalLine: (value) {
              return const FlLine(
                color: Color(0xFFE5E7EB),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: maxY > 0 ? (maxY / 4) : 1000,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trends.length) return const SizedBox();
                  final date = DateTime.parse(trends[index].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MMM d').format(date),
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trends.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.2, // Add 20% headroom
          lineBarsData: [
            LineChartBarData(
              spots: trends.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList(),
              isCurved: true,
              color: const Color(0xFF0F766E),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF0F766E).withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsChart(List<DailyTrendPoint> trends) {
    if (trends.isEmpty) return const SizedBox();

    final maxBookings = trends.map((t) => t.bookings).fold<int>(0, (m, v) => v > m ? v : m);
    
    return _ChartCard(
      title: 'Completed Bookings',
      chart: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxBookings > 0 ? (maxBookings / 4).ceilToDouble() : 5,
            getDrawingHorizontalLine: (value) {
              return const FlLine(
                color: Color(0xFFE5E7EB),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxBookings > 0 ? (maxBookings / 4).ceilToDouble() : 5,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 7,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= trends.length) return const SizedBox();
                  final date = DateTime.parse(trends[index].date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MMM d').format(date),
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          maxY: (maxBookings * 1.2).ceilToDouble(),
          barGroups: trends.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.bookings.toDouble(),
                  color: const Color(0xFF2563EB),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )
              ],
            );
          }).toList(),
        ),
      ),
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F766E).withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? const Color(0xFF0F766E).withValues(alpha: 0.3) : cs.outlineVariant),
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF0F766E) : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AnalyticsSummaryRow extends StatelessWidget {
  const _AnalyticsSummaryRow({
    required this.trends,
    required this.activeBookings,
  });

  final List<DailyTrendPoint> trends;
  final int activeBookings;

  @override
  Widget build(BuildContext context) {
    final totalRevenue = trends.fold<double>(0, (sum, point) => sum + point.revenue);
    final totalCommission = trends.fold<double>(0, (sum, point) => sum + point.commission);
    final totalBookings = trends.fold<int>(0, (sum, point) => sum + point.bookings);
    final totalWorkers = trends.fold<int>(0, (sum, point) => sum + point.newWorkers);
    final topRevenueDay = trends.isEmpty
        ? null
        : trends.reduce((a, b) => a.revenue >= b.revenue ? a : b);
    final topBookingsDay = trends.isEmpty
        ? null
        : trends.reduce((a, b) => a.bookings >= b.bookings ? a : b);

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricCard(
          label: 'Total GMV',
          value: '₹${NumberFormat.compact().format(totalRevenue)}',
          sublabel: '${trends.length} days tracked',
          icon: Icons.payments_rounded,
          color: const Color(0xFF0F766E),
        ),
        _MetricCard(
          label: 'Commission earned',
          value: '₹${NumberFormat.compact().format(totalCommission)}',
          sublabel: totalRevenue > 0
              ? '${(totalCommission / totalRevenue * 100).toStringAsFixed(1)}% of GMV'
              : 'No revenue yet',
          icon: Icons.percent_rounded,
          color: const Color(0xFF059669),
        ),
        _MetricCard(
          label: 'Completed bookings',
          value: '$totalBookings',
          sublabel: topBookingsDay == null ? 'No booking data' : 'Peak day ${DateFormat('MMM d').format(DateTime.parse(topBookingsDay.date))}',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF2563EB),
        ),
        _MetricCard(
          label: 'Live active jobs',
          value: '$activeBookings',
          sublabel: 'Right now across Chennai',
          icon: Icons.bolt_rounded,
          color: const Color(0xFFEA580C),
          isLive: true,
        ),
        _MetricCard(
          label: 'New workers',
          value: '$totalWorkers',
          sublabel: 'Average ${(trends.isEmpty ? 0 : totalWorkers / trends.length).toStringAsFixed(1)} per day',
          icon: Icons.person_add_alt_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _MetricCard(
          label: 'Best revenue day',
          value: topRevenueDay == null ? 'N/A' : '₹${NumberFormat.compact().format(topRevenueDay.revenue)}',
          sublabel: topRevenueDay == null ? 'No data' : DateFormat('MMM d').format(DateTime.parse(topRevenueDay.date)),
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF8B5CF6),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.color,
    this.isLive = false,
  });

  final String label;
  final String value;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(
          color: isLive
              ? color.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (isLive) ...
                [
                  _PulseDot(color: color),
                  const SizedBox(width: 6),
                ],
              Text(label,
                  style: tt.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(sublabel,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Pulsing red/orange dot for the live metric card.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.chart,
    this.subtitle,
    this.fullWidth = false,
  });

  final String title;
  final String? subtitle;
  final Widget chart;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: fullWidth ? 300 : 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...
            [
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.black45),
              ),
            ],
          const SizedBox(height: 24),
          Expanded(child: chart),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<AnalyticsBreakdownItem> items;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            Text('No breakdown data yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
          else
            Column(
              children: items
                  .take(5)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BreakdownRow(item: item),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.item});

  final AnalyticsBreakdownItem item;

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
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${item.bookings} bookings',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            '₹${NumberFormat.compact().format(item.revenue)}',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
