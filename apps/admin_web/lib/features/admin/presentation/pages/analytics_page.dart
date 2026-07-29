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
  List<DailyTrendPoint>? _trends;
  bool _isLoading = true;
  String? _error;

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
      final trends = await _api.fetchTrends(days: 30);
      if (mounted) {
        setState(() {
          _trends = trends;
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
            else if (_trends != null) ...[
              // Charts Area
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRevenueChart(_trends!)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildBookingsChart(_trends!)),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<DailyTrendPoint> trends) {
    if (trends.isEmpty) return const SizedBox();

    final maxY = trends.map((t) => t.revenue).fold<double>(0, (m, v) => v > m ? v : m);
    
    return _ChartCard(
      title: 'Revenue Trend (Rs.)',
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.chart});
  
  final String title;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
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
          const SizedBox(height: 24),
          Expanded(child: chart),
        ],
      ),
    );
  }
}
