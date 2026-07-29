import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  late final OpsApi _api;
  OpsOverviewSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snapshot = await _api.fetchOverview();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from AppShell
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor revenue, support, worker approvals, and marketplace health.',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Customize'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Top Metrics
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_snapshot != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final summary = _snapshot!.summary;
                  final isSmall = constraints.maxWidth < 800;
                  
                  final cards = [
                    _MetricCard(
                      title: 'Revenue',
                      value: 'Rs. ${summary.totalRevenue.toStringAsFixed(0)}',
                      icon: Icons.payments_rounded,
                      color: const Color(0xFF0F766E),
                      trend: '+12.5% vs last week',
                      trendUp: true,
                    ),
                    if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                    _MetricCard(
                      title: 'Bookings',
                      value: '${summary.totalBookings}',
                      icon: Icons.event_available_rounded,
                      color: const Color(0xFF2563EB),
                      trend: '+5.2% vs last week',
                      trendUp: true,
                    ),
                    if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                    _MetricCard(
                      title: 'Worker Approvals',
                      value: '${summary.pendingWorkerReviewsCount}',
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFFF59E0B),
                      subtitle: 'Pending review',
                      trend: '-2 since yesterday',
                      trendUp: false,
                    ),
                  ];
                  
                  if (isSmall) {
                    return Column(children: cards);
                  }
                  return Row(
                    children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
                  );
                },
              ),
            const SizedBox(height: 32),

            // Charts Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 1000;
                final charts = [
                  Expanded(
                    flex: isSmall ? 0 : 2,
                    child: const _GlassCard(
                      child: _RevenueChart(),
                    ),
                  ),
                  if (isSmall) const SizedBox(height: 32) else const SizedBox(width: 32),
                  Expanded(
                    flex: isSmall ? 0 : 1,
                    child: const _GlassCard(
                      child: _JobStatusChart(),
                    ),
                  ),
                ];
                
                if (isSmall) {
                  return Column(
                    children: charts.whereType<Expanded>().map((e) => e.child).toList(),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: charts,
                );
              },
            ),
            const SizedBox(height: 48),

            // Navigation Grid Sections
            Text(
              'Quick Navigation',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle(title: 'Operations'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Ops Overview',
                  subtitle: 'Monitor jobs, dispatch, and disputes',
                  icon: Icons.monitor_heart_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/ops/overview'),
                ),
                _ActionCard(
                  title: 'Live Jobs',
                  subtitle: 'Inspect active job execution states',
                  icon: Icons.work_history_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.go('/ops/live-jobs'),
                ),
                _ActionCard(
                  title: 'Alerts Queue',
                  subtitle: 'Retry failed payouts and refunds',
                  icon: Icons.priority_high_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => context.go('/ops/alerts'),
                ),
                _ActionCard(
                  title: 'Disputes',
                  subtitle: 'Review customer disputes',
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFFB45309),
                  onTap: () => context.go('/ops/disputes'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            const _SectionTitle(title: 'Catalog & Workers'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Catalog Manager',
                  subtitle: 'Categories, services, pricing',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.go('/catalog'),
                ),
                _ActionCard(
                  title: 'Worker Review',
                  subtitle: 'Approve or reject onboarding',
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.go('/worker-review'),
                ),
                _ActionCard(
                  title: 'Worker Directory',
                  subtitle: 'Browse all workers and performance',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/workers'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            const _SectionTitle(title: 'Finance & Analytics'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Finance',
                  subtitle: 'Payouts and refunds ledgers',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/finance'),
                ),
                _ActionCard(
                  title: 'Analytics',
                  subtitle: 'Marketplace performance trends',
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.go('/analytics'),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            Text(
              'Operations Snapshot',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_snapshot != null)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxWidth < 800;
                  final cards = [
                    _SnapshotCard(
                      label: 'Service completion rate',
                      value: '${_snapshot!.summary.totalBookings > 0 ? ((_snapshot!.summary.completedBookings / _snapshot!.summary.totalBookings) * 100).toStringAsFixed(1) : 0}%',
                    ),
                    if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                    _SnapshotCard(
                      label: 'Open support tickets',
                      value: '${_snapshot!.summary.openDisputesCount} active',
                    ),
                    if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                    _SnapshotCard(
                      label: 'Today\'s new workers',
                      value: '${_snapshot!.summary.todaysNewWorkers} apps',
                    ),
                  ];
                  
                  if (isSmall) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: cards,
                    );
                  }
                  return Row(
                    children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Revenue & Booking Velocity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.black.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(color: Colors.black54, fontWeight: FontWeight.w500, fontSize: 12);
                      Widget text;
                      switch (value.toInt()) {
                        case 0: text = const Text('Mon', style: style); break;
                        case 2: text = const Text('Wed', style: style); break;
                        case 4: text = const Text('Fri', style: style); break;
                        case 6: text = const Text('Sun', style: style); break;
                        default: text = const Text('', style: style); break;
                      }
                      return SideTitleWidget(meta: meta, child: text);
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      return Text('${value.toInt()}k', style: const TextStyle(color: Colors.black54, fontSize: 12));
                    },
                    reservedSize: 42,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: 6,
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 3),
                    FlSpot(1, 2),
                    FlSpot(2, 5),
                    FlSpot(3, 3.1),
                    FlSpot(4, 4),
                    FlSpot(5, 3),
                    FlSpot(6, 4),
                  ],
                  isCurved: true,
                  color: const Color(0xFF0F766E),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0F766E).withValues(alpha: 0.3),
                        const Color(0xFF0F766E).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 1),
                    FlSpot(1, 1.5),
                    FlSpot(2, 1.4),
                    FlSpot(3, 3.4),
                    FlSpot(4, 2),
                    FlSpot(5, 2.2),
                    FlSpot(6, 1.8),
                  ],
                  isCurved: true,
                  color: const Color(0xFF2563EB),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2563EB).withValues(alpha: 0.3),
                        const Color(0xFF2563EB).withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JobStatusChart extends StatelessWidget {
  const _JobStatusChart();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job Status',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 300,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(enabled: false),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  color: const Color(0xFF10B981),
                  value: 60,
                  title: '60%',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFF3B82F6),
                  value: 25,
                  title: '25%',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFFEF4444),
                  value: 10,
                  title: '10%',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                PieChartSectionData(
                  color: const Color(0xFFF59E0B),
                  value: 5,
                  title: '5%',
                  radius: 30,
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _LegendItem(color: Color(0xFF10B981), label: 'Done'),
            _LegendItem(color: Color(0xFF3B82F6), label: 'Active'),
            _LegendItem(color: Color(0xFFEF4444), label: 'Cancel'),
            _LegendItem(color: Color(0xFFF59E0B), label: 'Dispute'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
    this.trendUp = true,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -1,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                color: Colors.black45,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
          if (trend != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 16,
                  color: trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 4),
                Text(
                  trend!,
                  style: GoogleFonts.inter(
                    color: trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
