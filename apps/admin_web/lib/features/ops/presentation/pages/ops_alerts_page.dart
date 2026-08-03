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
      context.push('/ops/live-jobs/${alert.bookingId}');
      return;
    }

    await context.push('/ops/alerts/${alert.id}');
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
      backgroundColor: Colors.transparent,
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

          return RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
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
                            'Unified Alerts Queue',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Handle failed dispatches, refunds, payouts, and payment mismatches from one queue.',
                            style: GoogleFonts.inter(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _reload,
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
                    spacing: 12,
                    runSpacing: 12,
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
                      _InfoChip(
                          label:
                              '${alerts.where((alert) => alert.isPaymentMismatch).length} payment mismatches'),
                    ],
                  ),
                  const SizedBox(height: 32),
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
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _SurfacePanel(
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
                        );
                      },
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

class OpsAlertDetailPage extends ConsumerStatefulWidget {
  const OpsAlertDetailPage({
    super.key,
    required this.alertId,
    this.initialAlert,
  });

  final String alertId;
  final OpsAlert? initialAlert;

  @override
  ConsumerState<OpsAlertDetailPage> createState() => _OpsAlertDetailPageState();
}

class _OpsAlertDetailPageState extends ConsumerState<OpsAlertDetailPage> {
  late final OpsApi _api;
  late Future<OpsAlert?> _alertFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _alertFuture = _loadAlert();
  }

  Future<OpsAlert?> _loadAlert() async {
    if (widget.initialAlert != null && widget.initialAlert!.id == widget.alertId) {
      return widget.initialAlert;
    }

    final snapshot = await _api.fetchOverview();
    for (final alert in snapshot.alerts) {
      if (alert.id == widget.alertId) {
        return alert;
      }
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
      _alertFuture = _loadAlert();
    });
    await _alertFuture;
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Alert Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<OpsAlert?>(
        future: _alertFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                      'Unable to load alert',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final alert = snapshot.data;
          if (alert == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Alert not found',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This alert is no longer present in the current snapshot.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _reload, child: const Text('Reload')),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AlertIcon(kind: alert.kind),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(
                          alert.message,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (alert.retryAvailable) _RetryBadge(kind: alert.kind),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (alert.bookingCode != null) _InfoChip(label: 'Booking ${alert.bookingCode}'),
                  if (alert.customerName != null) _InfoChip(label: alert.customerName!),
                  _InfoChip(label: MaterialLocalizations.of(context).formatMediumDate(alert.createdAt)),
                  if (alert.amount != null) _InfoChip(label: 'Rs. ${alert.amount!.toStringAsFixed(2)}'),
                  _InfoChip(label: alert.kind.replaceAll('_', ' ')),
                ],
              ),
              const SizedBox(height: 18),
              if (alert.isDispatchFailure && alert.bookingId != null)
                FilledButton.icon(
                  onPressed: () => context.push('/ops/live-jobs/${alert.bookingId}'),
                  icon: const Icon(Icons.work_rounded),
                  label: const Text('Open live job'),
                ),
              const SizedBox(height: 16),
              Text('Actions', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (alert.retryAvailable)
                    FilledButton(
                      onPressed: _busy ? null : () => _retryAlert(alert),
                      child: const Text('Retry'),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : _reload,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
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
      'payment_mismatch' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };

    final icon = switch (kind) {
      'payout_failure' => Icons.payments_rounded,
      'refund_failure' => Icons.undo_rounded,
      'payment_mismatch' => Icons.currency_rupee_rounded,
      _ => Icons.notification_important_rounded,
    };

    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
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
      'payment_mismatch' => 'Investigate',
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

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: child,
    );
  }
}
