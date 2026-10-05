import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class SystemHealthPage extends ConsumerStatefulWidget {
  const SystemHealthPage({super.key});

  @override
  ConsumerState<SystemHealthPage> createState() => _SystemHealthPageState();
}

class _SystemHealthPageState extends ConsumerState<SystemHealthPage> {
  Timer? _refreshTimer;
  bool _refreshInFlight = false;
  bool _loading = true;
  bool _reachable = false;
  bool _healthy = false;
  String? _error;
  String _database = 'unknown';
  String _redis = 'unknown';
  DateTime? _checkedAt;
  Duration? _latency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    if (!silent && mounted) setState(() => _loading = true);
    final startedAt = DateTime.now();
    try {
      final response = await ref.read(apiClientProvider).dio.get<dynamic>(
            '/admin/system-health',
            options: Options(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
      _applyHealthResponse(
        response.data,
        response.statusCode,
        DateTime.now().difference(startedAt),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      if (error.response != null && body is Map) {
        _applyHealthResponse(
          body,
          error.response?.statusCode,
          DateTime.now().difference(startedAt),
        );
      } else if (error.response != null && mounted) {
        setState(() {
          _reachable = true;
          _healthy = false;
          _error = 'The health endpoint returned an unexpected response.';
          _checkedAt = DateTime.now();
          _latency = DateTime.now().difference(startedAt);
        });
      } else if (mounted) {
        setState(() {
          _reachable = false;
          _healthy = false;
          _error = 'The health endpoint could not be reached.';
          _checkedAt = DateTime.now();
          _latency = DateTime.now().difference(startedAt);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reachable = false;
          _healthy = false;
          _error = 'The health endpoint could not be reached.';
          _checkedAt = DateTime.now();
          _latency = DateTime.now().difference(startedAt);
        });
      }
    } finally {
      _refreshInFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyHealthResponse(dynamic body, int? statusCode, Duration latency) {
    if (!mounted || body is! Map) return;
    setState(() {
      _reachable = true;
      _healthy = statusCode == 200 && body['ok'] == true;
      _database = _componentState(body['postgres']);
      _redis = _componentState(body['redis']);
      _error = _healthy ? null : 'One or more backend checks are unhealthy.';
      _checkedAt = DateTime.now();
      _latency = latency;
    });
  }

  String _componentState(dynamic value) => switch (value) {
        'up' => 'Operational',
        'down' => 'Unavailable',
        _ => 'Unknown',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = !_reachable
        ? const Color(0xFFDC2626)
        : _healthy
            ? const Color(0xFF059669)
            : const Color(0xFFD97706);
    final statusLabel = !_reachable
        ? 'API unreachable'
        : _healthy
            ? 'All systems operational'
            : 'Service degradation detected';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Health',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor API, database, and cache availability.',
                        style: GoogleFonts.inter(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _loading ? null : () => _refresh(),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_loading ? 'Checking…' : 'Check now'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Card(
              elevation: 0,
              color: statusColor.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: statusColor.withValues(alpha: 0.28)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Icon(
                      !_reachable
                          ? Icons.cloud_off_rounded
                          : _healthy
                              ? Icons.check_circle_rounded
                              : Icons.warning_amber_rounded,
                      color: statusColor,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 4),
                            Text(_error!),
                          ],
                        ],
                      ),
                    ),
                    if (_checkedAt != null)
                      Text(
                        'Checked ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_checkedAt!.toLocal()))}',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 560
                        ? 2
                        : 1;
                final cardWidth =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _HealthCard(
                      width: cardWidth,
                      title: 'Backend API',
                      value: _reachable ? 'Reachable' : 'Unavailable',
                      detail: _latency == null
                          ? 'No response yet'
                          : '${_latency!.inMilliseconds} ms response',
                      icon: Icons.api_rounded,
                      operational: _reachable,
                    ),
                    _HealthCard(
                      width: cardWidth,
                      title: 'PostgreSQL',
                      value: _database,
                      detail: 'Database connectivity check',
                      icon: Icons.storage_rounded,
                      operational: _database == 'Operational',
                    ),
                    _HealthCard(
                      width: cardWidth,
                      title: 'Redis',
                      value: _redis,
                      detail: 'Cache and queue connectivity check',
                      icon: Icons.memory_rounded,
                      operational: _redis == 'Operational',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              'Checks refresh automatically once per minute while this page is open. The status reflects the latest health endpoint response.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.width,
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.operational,
  });

  final double width;
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final bool operational;

  @override
  Widget build(BuildContext context) {
    final color = value == 'Unknown'
        ? const Color(0xFF64748B)
        : operational
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626);
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF475569)),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
