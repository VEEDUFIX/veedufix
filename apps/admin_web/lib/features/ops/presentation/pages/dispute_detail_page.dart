import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/disputes_api.dart';

class DisputeDetailPage extends ConsumerStatefulWidget {
  const DisputeDetailPage({
    super.key,
    required this.disputeId,
  });

  final String disputeId;

  @override
  ConsumerState<DisputeDetailPage> createState() => _DisputeDetailPageState();
}

class _DisputeDetailPageState extends ConsumerState<DisputeDetailPage> {
  late final DisputesApi _api;
  late Future<DisputeEvidence> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _api = DisputesApi(ref.read(apiClientProvider).dio);
    _future = _api.fetchDispute(widget.disputeId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchDispute(widget.disputeId);
    });
    await _future;
  }

  Future<void> _resolve({
    required String resolution,
    required String title,
    required String buttonLabel,
    required String description,
    required double amount,
  }) async {
    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description),
                const SizedBox(height: 12),
                if (resolution == 'refund')
                  _InfoLine(
                    label: 'Refund amount',
                    value: 'Rs. ${amount.toStringAsFixed(2)}',
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'Add a clear resolution note',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(noteController.text.trim()),
              child: Text(buttonLabel),
            ),
          ],
        );
      },
    );

    if (note == null || note.trim().isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      await _api.resolveDispute(widget.disputeId,
          resolution: resolution, note: note);
      if (!mounted) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute resolved')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showImage(String url) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: InteractiveViewer(
            child: MarketplaceNetworkImage(
              imageUrl: url,
              width: 400,
              height: 240,
              fit: BoxFit.contain,
              borderRadius: 0,
              optimizeCloudinary: false,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Dispute detail',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<DisputeEvidence>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final dispute = snapshot.data!.dispute;
          final booking = snapshot.data!.booking;
          final isResolved = dispute.status.startsWith('resolved_');

          return Container(
            color: Colors.transparent,
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
                            booking.code,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complaint review, job evidence, and resolution history.',
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
                              _Chip(label: dispute.status.replaceAll('_', ' ')),
                              _Chip(label: booking.cityName),
                              _Chip(
                                  label: booking.workerName ??
                                      'Worker unavailable'),
                              _Chip(
                                  label:
                                      'Rs. ${booking.totalAmount.toStringAsFixed(2)}'),
                              _Chip(
                                  label: MaterialLocalizations.of(context)
                                      .formatMediumDate(dispute.createdAt)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(booking.code, 'Booking code'),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy booking code'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(dispute.id, 'Dispute ID'),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy dispute ID'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final left = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SurfacePanel(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dispute reason',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(dispute.reason),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Customer comment',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(booking.customerNotes
                                              ?.trim()
                                              .isNotEmpty ==
                                          true
                                      ? booking.customerNotes!.trim()
                                      : 'No separate customer comment provided.'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SurfacePanel(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Job evidence',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Before photos',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  _PhotoGallery(
                                      urls: booking.beforePhotos,
                                      onTap: _showImage),
                                  const SizedBox(height: 12),
                                  Text(
                                    'After photos',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  _PhotoGallery(
                                      urls: booking.afterPhotos,
                                      onTap: _showImage),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Checklist',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  if (booking.checklist.isEmpty)
                                    const Text(
                                        'No checklist items were returned with the job evidence.')
                                  else
                                    ...booking.checklist.map(
                                      (item) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.complete
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                      .radio_button_unchecked_rounded,
                                              color: item.complete
                                                  ? const Color(0xFF0F766E)
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .outline,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(item.label)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );

                      final right = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SurfacePanel(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Resolution',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 12),
                                  _InfoLine(
                                      label: 'Status',
                                      value:
                                          dispute.status.replaceAll('_', ' ')),
                                  _InfoLine(
                                      label: 'Raised',
                                      value: MaterialLocalizations.of(context)
                                          .formatMediumDate(dispute.createdAt)),
                                  _InfoLine(
                                      label: 'Worker',
                                      value: booking.workerName ??
                                          'Not returned by API'),
                                  if (booking.completedAt != null)
                                    _InfoLine(
                                        label: 'Completed',
                                        value: MaterialLocalizations.of(context)
                                            .formatMediumDate(
                                                booking.completedAt!)),
                                  if (dispute.resolvedAt != null)
                                    _InfoLine(
                                        label: 'Resolved',
                                        value: MaterialLocalizations.of(context)
                                            .formatMediumDate(
                                                dispute.resolvedAt!)),
                                  if ((dispute.resolutionNote ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _InfoLine(
                                        label: 'Resolution note',
                                        value: dispute.resolutionNote!.trim()),
                                  if ((dispute.refundId ?? '').trim().isNotEmpty)
                                    _InfoLine(
                                        label: 'Refund ID',
                                        value: dispute.refundId!.trim()),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (!isResolved)
                            _SurfacePanel(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Actions',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _resolve(
                                                resolution: 'refund',
                                                title: 'Approve refund',
                                                buttonLabel: 'Approve',
                                                description:
                                                    'This will refund the full booking amount for the disputed job. Please confirm the amount and add a short note for the audit trail.',
                                                amount: booking.totalAmount,
                                              ),
                                      icon: const Icon(Icons.reply_rounded),
                                      label: const Text('Approve Refund'),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _resolve(
                                                resolution: 'reject',
                                                title: 'Reject dispute',
                                                buttonLabel: 'Reject',
                                                description:
                                                    'Use this when the job evidence does not support a refund. Add a concise reason for the decision.',
                                                amount: booking.totalAmount,
                                              ),
                                      icon: const Icon(Icons.close_rounded),
                                      label: const Text('Reject Dispute'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            _SurfacePanel(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Resolution history',
                                      style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 12),
                                    _InfoLine(
                                        label: 'Final status',
                                        value: dispute.status
                                            .replaceAll('_', ' ')),
                                    _InfoLine(
                                        label: 'Note',
                                        value: dispute.resolutionNote ??
                                            'No note recorded'),
                                    _InfoLine(
                                        label: 'Resolved by',
                                        value: dispute.resolvedBy ?? 'Unknown'),
                                    _InfoLine(
                                      label: 'Resolved at',
                                      value: dispute.resolvedAt == null
                                          ? 'Unknown'
                                          : MaterialLocalizations.of(context)
                                              .formatMediumDate(
                                                  dispute.resolvedAt!),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: left),
                            const SizedBox(width: 16),
                            Expanded(child: right),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          left,
                          const SizedBox(height: 16),
                          right,
                        ],
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

class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({
    required this.urls,
    required this.onTap,
  });

  final List<String> urls;
  final Future<void> Function(String url) onTap;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const Text('No photos provided.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: urls.map(
        (url) {
          return GestureDetector(
            onTap: () => onTap(url),
            child: MarketplaceNetworkImage(
              imageUrl: url,
              width: 132,
              height: 132,
              fit: BoxFit.cover,
              borderRadius: AbzioTheme.buttonRadius,
              cloudinaryWidth: 240,
              cloudinaryHeight: 240,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          );
        },
      ).toList(growable: false),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
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
            width: 116,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

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
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load dispute detail',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
