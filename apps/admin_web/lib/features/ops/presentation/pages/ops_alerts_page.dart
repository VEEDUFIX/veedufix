import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/ops_api.dart';

class OpsAlertsPage extends ConsumerStatefulWidget {
  const OpsAlertsPage({super.key});

  @override
  ConsumerState<OpsAlertsPage> createState() => _OpsAlertsPageState();
}

class _OpsAlertsPageState extends ConsumerState<OpsAlertsPage> {
  late final OpsApi _api;
  late Future<OpsOverviewSnapshot> _snapshotFuture;
  bool _busy = false;

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

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action completed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _viewAlert(OpsAlert alert) async {
    if (alert.isDispatchFailure && alert.bookingId != null) {
      context.go('/ops/live-jobs');
      return;
    }

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(alert.title),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.message),
                const SizedBox(height: 12),
                _Line(
                    label: 'Booking', value: alert.bookingCode ?? 'Not linked'),
                _Line(
                    label: 'Customer', value: alert.customerName ?? 'Unknown'),
                _Line(
                    label: 'Created',
                    value: MaterialLocalizations.of(context)
                        .formatMediumDate(alert.createdAt)),
                if (alert.amount != null)
                  _Line(
                      label: 'Amount',
                      value: 'Rs. ${alert.amount!.toStringAsFixed(2)}'),
              ],
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

  Future<void> _retryAlert(OpsAlert alert) async {
    if (!alert.retryAvailable || alert.sourceId == null) {
      return;
    }

    if (alert.isDispatchFailure) {
      await _runAction(() => _api.redispatchBooking(alert.sourceId!));
      return;
    }

    if (alert.isPayoutFailure) {
      await _runAction(() => _api.retryPayout(alert.sourceId!));
      return;
    }

    if (alert.isRefundFailure) {
      await _runAction(() => _api.retryRefund(alert.sourceId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Operations alerts',
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
                      'Unable to load operations alerts',
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

          final alerts = snapshot.data?.alerts ?? const <OpsAlert>[];

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
                            'Unified alerts queue',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF13110F),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Handle failed dispatches, refunds, and payouts from one queue without switching modules.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B6256),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoChip(
                                  label:
                                      '${alerts.where((alert) => alert.isDispatchFailure).length} dispatch failures'),
                              _InfoChip(
                                  label:
                                      '${alerts.where((alert) => alert.isPayoutFailure).length} payout failures'),
                              _InfoChip(
                                  label:
                                      '${alerts.where((alert) => alert.isRefundFailure).length} refund failures'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (alerts.isEmpty)
                    const _SurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PremiumEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'Nothing needs attention',
                          subtitle:
                              'Dispatch failures, payout retries, and refund retries will appear here when they happen.',
                        ),
                      ),
                    )
                  else
                    ...alerts.map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SurfacePanel(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _AlertIcon(kind: alert.kind),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(alert.title,
                                              style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(
                                            alert.message,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (alert.retryAvailable)
                                      _RetryBadge(kind: alert.kind),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (alert.bookingCode != null)
                                      _InfoChip(
                                          label:
                                              'Booking ${alert.bookingCode}'),
                                    if (alert.customerName != null)
                                      _InfoChip(label: alert.customerName!),
                                    _InfoChip(
                                        label: MaterialLocalizations.of(context)
                                            .formatMediumDate(alert.createdAt)),
                                    if (alert.amount != null)
                                      _InfoChip(
                                          label:
                                              'Rs. ${alert.amount!.toStringAsFixed(2)}'),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _viewAlert(alert),
                                      child: const Text('View'),
                                    ),
                                    if (alert.retryAvailable)
                                      FilledButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _retryAlert(alert),
                                        child: const Text('Retry'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
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

class _AlertIcon extends StatelessWidget {
  const _AlertIcon({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      'payout_failure' => const Color(0xFF0F766E),
      'refund_failure' => const Color(0xFF8B5CF6),
      _ => const Color(0xFFEF4444),
    };

    final icon = switch (kind) {
      'payout_failure' => Icons.payments_rounded,
      'refund_failure' => Icons.undo_rounded,
      _ => Icons.notification_important_rounded,
    };

    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _RetryBadge extends StatelessWidget {
  const _RetryBadge({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'payout_failure' => 'Retry payout',
      'refund_failure' => 'Retry refund',
      _ => 'Redispatch',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
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
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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
