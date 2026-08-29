import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../ops/data/ops_api.dart';
import 'dashboard_shared.dart';

class DashboardCharts extends StatelessWidget {
  const DashboardCharts({
    super.key,
    required this.isLoading,
    this.snapshot,
    this.error,
    this.onRetry,
  });

  final bool isLoading;
  final OpsOverviewSnapshot? snapshot;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 1000;
          if (isSmall) {
            return const Column(
              children: [
                _ChartSkeletonCard(titleWidth: 160),
                SizedBox(height: 32),
                _ChartSkeletonCard(titleWidth: 110),
              ],
            );
          }

          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ChartSkeletonCard(titleWidth: 160)),
              SizedBox(width: 32),
              Expanded(child: _ChartSkeletonCard(titleWidth: 110)),
            ],
          );
        },
      );
    }

    if (error != null) {
      return PremiumEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load dashboard charts',
        subtitle: 'The live admin charts are unavailable right now. Please retry.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    final data = snapshot;
    if (data == null) {
      return const PremiumEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No dashboard data yet',
        subtitle: 'Live operational charts will appear once the overview API returns data.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 1000;
        final charts = [
          Expanded(
            flex: isSmall ? 0 : 2,
            child: _WorkloadChart(summary: data.summary),
          ),
          if (isSmall) const SizedBox(height: 32) else const SizedBox(width: 32),
          Expanded(
            flex: isSmall ? 0 : 1,
            child: _OperationsMixChart(summary: data.summary),
          ),
        ];

        if (isSmall) {
          return Column(
            children: charts.whereType<Expanded>().map((chart) => chart.child).toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: charts,
        );
      },
    );
  }
}

class _WorkloadChart extends StatelessWidget {
  const _WorkloadChart({required this.summary});

  final OpsSummaryCounts summary;

  @override
  Widget build(BuildContext context) {
    final bars = <_WorkloadBar>[
      _WorkloadBar('Active', summary.activeJobsCount, const Color(0xFF2563EB)),
      _WorkloadBar('Dispatch', summary.dispatchFailuresCount, const Color(0xFFEF4444)),
      _WorkloadBar('Disputes', summary.openDisputesCount, const Color(0xFFF59E0B)),
      _WorkloadBar('Payouts', summary.failedPayoutsCount, const Color(0xFF0F766E)),
      _WorkloadBar('Refunds', summary.failedRefundsCount, const Color(0xFF8B5CF6)),
      _WorkloadBar('Reviews', summary.pendingWorkerReviewsCount, const Color(0xFF14B8A6)),
    ];
    final maxY = math.max(
      1,
      bars.map((bar) => bar.value).fold<int>(0, math.max),
    ).toDouble();
    final interval = math.max(1.0, (maxY / 4).ceilToDouble());

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live workload',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Current operational queue pressure across dispatch, finance, and reviews.',
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.25,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: interval,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[index].label,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: bars.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bar = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: bar.value.toDouble(),
                        width: 18,
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            bar.color,
                            bar.color.withValues(alpha: 0.55),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsMixChart extends StatelessWidget {
  const _OperationsMixChart({required this.summary});

  final OpsSummaryCounts summary;

  @override
  Widget build(BuildContext context) {
    final slices = <_PieSlice>[
      _PieSlice('Active jobs', summary.activeJobsCount, const Color(0xFF2563EB)),
      _PieSlice('Dispatch failures', summary.dispatchFailuresCount, const Color(0xFFEF4444)),
      _PieSlice('Open disputes', summary.openDisputesCount, const Color(0xFFF59E0B)),
      _PieSlice('Failed payouts', summary.failedPayoutsCount, const Color(0xFF0F766E)),
      _PieSlice('Failed refunds', summary.failedRefundsCount, const Color(0xFF8B5CF6)),
      _PieSlice('Worker reviews', summary.pendingWorkerReviewsCount, const Color(0xFF14B8A6)),
    ].where((slice) => slice.value > 0).toList(growable: false);

    if (slices.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No live operations to show',
        subtitle: 'This snapshot is clean for now, so the operations mix is empty.',
      );
    }

    final total = slices.fold<int>(0, (sum, slice) => sum + slice.value);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Operations mix',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share of the current issue queue by category.',
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: false),
                borderData: FlBorderData(show: false),
                sectionsSpace: 2,
                centerSpaceRadius: 66,
                sections: slices.map((slice) {
                  return PieChartSectionData(
                    color: slice.color,
                    value: slice.value.toDouble(),
                    title: '${slice.value}',
                    radius: 34,
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  '$total open',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'live operational items',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slices.map((slice) {
              return _LegendChip(
                color: slice.color,
                label: slice.label,
                value: slice.value,
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ChartSkeletonCard extends StatelessWidget {
  const _ChartSkeletonCard({required this.titleWidth});

  final double titleWidth;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerWidget(width: titleWidth, height: 18, radius: 8),
          const SizedBox(height: 6),
          const ShimmerWidget(width: 240, height: 12, radius: 6),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                6,
                (index) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShimmerWidget(width: double.infinity, height: 90, radius: 18),
                        SizedBox(height: 10),
                        ShimmerWidget(width: 48, height: 10, radius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkloadBar {
  const _WorkloadBar(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _PieSlice {
  const _PieSlice(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label · $value',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
