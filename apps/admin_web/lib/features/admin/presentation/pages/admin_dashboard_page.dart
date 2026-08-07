import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_kpi_grid.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/dashboard_quick_nav.dart';
import '../widgets/dashboard_ops_snapshot.dart';

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
    final isCompact = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from AppShell
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeader(isCompact: isCompact),
            const SizedBox(height: 32),
            
            DashboardKpiGrid(
              isCompact: isCompact,
              isLoading: _isLoading,
              snapshot: _snapshot,
            ),
            const SizedBox(height: 32),
            
            const DashboardCharts(),
            const SizedBox(height: 48),
            
            const DashboardQuickNav(),
            const SizedBox(height: 48),
            
            DashboardOpsSnapshot(
              isLoading: _isLoading,
              snapshot: _snapshot,
            ),
          ],
        ),
      ),
    );
  }
}
