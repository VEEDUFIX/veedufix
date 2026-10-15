import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                    value: '₹${amount.toStringAsFixed(2)}',
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
      final result = await _api.resolveDispute(widget.disputeId,
          resolution: resolution, note: note);
      if (!mounted) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resolution == 'refund'
              ? result.status == 'resolved_refund'
                  ? 'Refund completed by the payment provider'
                  : result.status == 'refund_pending'
                      ? 'Refund approved and processing; completion is still pending'
                      : result.status == 'under_review'
                          ? 'Refund did not complete; the claim returned to review'
                          : 'Claim status updated: ${result.status.replaceAll('_', ' ')}'
              : 'Claim rejected'),
        ),
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

  Future<void> _updateClaim(String action, String title,
      {String visibility = 'CUSTOMER'}) async {
    DateTime? scheduledAt;
    if (action == 'schedule_rework') {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 90)),
      );
      if (!mounted || date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
      );
      if (!mounted || time == null) return;
      scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!scheduledAt.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a revisit time in the future.')),
        );
        return;
      }
    }
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ClaimNoteDialog(title: title, visibility: visibility),
    );
    if (message == null || message.trim().length < 3) return;
    setState(() => _busy = true);
    try {
      await _api.updateClaim(widget.disputeId,
          action: action,
          message: message,
          visibility: visibility,
          scheduledAt: scheduledAt);
      if (!mounted) return;
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Claim updated')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
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
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
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
          final isResolved = dispute.status.startsWith('resolved_') ||
              dispute.status == 'closed';
          final canResolveRefund = <String>{
            'open',
            'under_review',
            'action_required',
          }.contains(dispute.status);
          final canRequestInfo = <String>{
            'open',
            'under_review',
            'approved',
          }.contains(dispute.status);
          final canChangeRemedy = !<String>{
            'scheduled',
            'completed',
            'customer_confirmed',
          }.contains(dispute.remedyStatus);
          Map<String, dynamic>? claimPolicy;
          if (dispute.serviceId != null) {
            for (final entry in booking.servicePolicies) {
              if (entry['serviceId'] == dispute.serviceId) {
                claimPolicy = entry['policy'] as Map<String, dynamic>?;
                break;
              }
            }
          } else if (booking.servicePolicies.length == 1) {
            // The backend applies the only booking service's policy when the
            // claim is not tied to a specific service.
            claimPolicy = booking.servicePolicies.single['policy']
                as Map<String, dynamic>?;
          }
          final policyEnabled = claimPolicy?['enabled'] == true;
          final canRefund = !policyEnabled ||
              (claimPolicy?['resolutionTypes'] as List? ?? const [])
                  .contains('REFUND_REVIEW');
          final canRework = claimPolicy?['enabled'] == true &&
              (claimPolicy?['resolutionTypes'] as List? ?? const []).any(
                (type) => type == 'REWORK' || type == 'REVISIT',
              );
          final bookingLookup =
              booking.code.trim().isNotEmpty ? booking.code.trim() : booking.id;
          final customerLookup = (booking.customerPhone ?? '').trim().isNotEmpty
              ? booking.customerPhone!.trim()
              : booking.id;

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
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complaint review, job evidence, and resolution history.',
                            style: GoogleFonts.outfit(
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
                                      '₹${booking.totalAmount.toStringAsFixed(2)}'),
                              _Chip(
                                  label: MaterialLocalizations.of(context)
                                      .formatMediumDate(dispute.createdAt)),
                            ],
                          ),
                          if (booking.servicePolicies.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Policy saved with this booking',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            for (final entry in booking.servicePolicies) ...[
                              Builder(builder: (context) {
                                final policy =
                                    entry['policy'] as Map<String, dynamic>;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '${entry['serviceName']}${entry['serviceId'] == dispute.serviceId ? ' · claim service' : ''}: ${policy['enabled'] == true ? 'covered for ${policy['claimWindowDays'] ?? 0} days' : 'no configured guarantee'}${(policy['terms'] as String?)?.trim().isNotEmpty == true ? '\nTerms: ${policy['terms']}' : ''}${(policy['exclusions'] as String?)?.trim().isNotEmpty == true ? '\nExclusions: ${policy['exclusions']}' : ''}${(policy['issueCategories'] as List?)?.isNotEmpty == true ? '\nEligible issues: ${(policy['issueCategories'] as List).join(', ')}' : ''}${(policy['resolutionTypes'] as List?)?.isNotEmpty == true ? '\nPermitted remedies: ${(policy['resolutionTypes'] as List).join(', ')}' : ''}${policy['evidenceRequired'] == true ? '\nSupporting evidence required' : ''}${policy['requiresPartnerReview'] == true ? '\nPartner review required' : ''}',
                                    style: GoogleFonts.outfit(
                                        color: const Color(0xFF6B6256)),
                                  ),
                                );
                              }),
                            ],
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _copyToClipboard(
                                    booking.code, 'Booking code'),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy booking code'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _copyToClipboard(dispute.id, 'Dispute ID'),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy dispute ID'),
                              ),
                              if ((dispute.refundId ?? '').trim().isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => context.push(
                                      '/finance/refunds/${dispute.refundId!.trim()}'),
                                  icon: const Icon(Icons.receipt_long_rounded),
                                  label: const Text('Open refund'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => context
                                    .push('/admin-bookings/${booking.id}'),
                                icon: const Icon(Icons.event_note_rounded),
                                label: const Text('Open booking'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push(
                                    '/admin-bookings?search=${Uri.encodeComponent(bookingLookup)}'),
                                icon: const Icon(Icons.search_rounded),
                                label: const Text('Booking search'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push(
                                    '/support-tickets?search=${Uri.encodeComponent(customerLookup)}'),
                                icon: const Icon(Icons.support_agent_rounded),
                                label: const Text('Support'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push(
                                    '/audit-logs?search=${Uri.encodeComponent(dispute.id)}'),
                                icon: const Icon(Icons.history_rounded),
                                label: const Text('Audit trail'),
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
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(dispute.reason),
                                  if (dispute.issueCategory?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 8),
                                    _InfoLine(
                                        label: 'Issue category',
                                        value: dispute.issueCategory!
                                            .replaceAll('_', ' ')),
                                  ],
                                  if (dispute.referenceCode?.isNotEmpty == true)
                                    _InfoLine(
                                        label: 'Claim reference',
                                        value: dispute.referenceCode!),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Customer comment',
                                    style: GoogleFonts.outfit(
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
                                    style: GoogleFonts.outfit(
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
                                  if (dispute.evidencePhotoIds.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    BookingDiagnosticPhotosSection(
                                      bookingId: booking.id,
                                      photoIds: dispute.evidencePhotoIds,
                                    ),
                                  ],
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
                                    style: GoogleFonts.outfit(
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
                                  _InfoLine(
                                      label: 'Booking ID', value: booking.id),
                                  _InfoLine(
                                      label: 'Booking code',
                                      value: booking.code),
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
                                  if ((dispute.refundId ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    _InfoLine(
                                        label: 'Refund ID',
                                        value: dispute.refundId!.trim()),
                                  if ((dispute.remedyType ?? '').isNotEmpty)
                                    _InfoLine(
                                      label: 'Approved remedy',
                                      value: dispute.remedyType!,
                                    ),
                                  if ((dispute.remedyStatus ?? '').isNotEmpty)
                                    _InfoLine(
                                      label: 'Remedy status',
                                      value: dispute.remedyStatus!
                                          .replaceAll('_', ' '),
                                    ),
                                  if (dispute.reworkProposedAt != null)
                                    _InfoLine(
                                      label: 'Partner proposal',
                                      value: MaterialLocalizations.of(context)
                                          .formatMediumDate(dispute
                                              .reworkProposedAt!
                                              .toLocal()),
                                    ),
                                  if (dispute.reworkScheduledAt != null)
                                    _InfoLine(
                                      label: 'Revisit scheduled',
                                      value:
                                          '${MaterialLocalizations.of(context).formatMediumDate(dispute.reworkScheduledAt!.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(dispute.reworkScheduledAt!.toLocal()))}',
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (booking.paymentRecords.isNotEmpty)
                            _SurfacePanel(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Payment records',
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    for (final payment
                                        in booking.paymentRecords) ...[
                                      _InfoLine(
                                        label:
                                            '${payment['status'] ?? 'Payment'} · ${payment['currency'] ?? 'INR'}',
                                        value:
                                            '₹${(double.tryParse(payment['amount']?.toString() ?? '') ?? 0).toStringAsFixed(2)}${payment['customQuoteRevisionId'] == null ? '' : ' · quotation payment'}',
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          if (booking.paymentRecords.isNotEmpty)
                            const SizedBox(height: 16),
                          if (dispute.history.isNotEmpty) ...[
                            _SurfacePanel(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Claim history',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    for (final event in dispute.history)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading:
                                            const Icon(Icons.history_rounded),
                                        title: Text(
                                          (event['type'] as String? ?? 'update')
                                              .replaceAll('_', ' '),
                                        ),
                                        subtitle: Text(
                                          event['message'] as String? ??
                                              'No message',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (!isResolved)
                            _SurfacePanel(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Actions',
                                      style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => context.push(
                                          '/audit-logs?search=${Uri.encodeComponent(booking.id)}'),
                                      icon: const Icon(Icons.history_rounded),
                                      label: const Text(
                                          'Open booking audit trail'),
                                    ),
                                    if (canRequestInfo && canChangeRemedy) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateClaim('request_info',
                                                'Request more information'),
                                        icon: const Icon(
                                            Icons.help_outline_rounded),
                                        label: const Text(
                                            'Request more information'),
                                      ),
                                    ],
                                    if (canRework &&
                                        canResolveRefund &&
                                        canChangeRemedy) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateClaim(
                                                'approve_rework',
                                                'Approve corrective-work claim'),
                                        icon: const Icon(
                                            Icons.build_circle_outlined),
                                        label: const Text(
                                            'Approve corrective-work claim'),
                                      ),
                                    ],
                                    if (dispute.remedyStatus ==
                                        'awaiting_admin_schedule') ...[
                                      const SizedBox(height: 8),
                                      FilledButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateClaim(
                                                  'schedule_rework',
                                                  'Confirm corrective-work appointment',
                                                ),
                                        icon: const Icon(
                                            Icons.event_available_outlined),
                                        label: const Text(
                                            'Confirm revisit appointment'),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _updateClaim(
                                                'internal_note',
                                                'Add internal note',
                                                visibility: 'INTERNAL',
                                              ),
                                      icon: const Icon(
                                          Icons.lock_outline_rounded),
                                      label: const Text('Add internal note'),
                                    ),
                                    if (canRefund && canResolveRefund) ...[
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
                                    ],
                                    if (canChangeRemedy &&
                                        dispute.status == 'approved') ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _updateClaim(
                                                'reject', 'Reject claim'),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Reject claim'),
                                      ),
                                    ] else if (canResolveRefund) ...[
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _resolve(
                                                  resolution: 'reject',
                                                  title: 'Reject dispute',
                                                  buttonLabel: 'Reject',
                                                  description:
                                                      'Use this when the job evidence does not support the claim. Add a concise reason for the decision.',
                                                  amount: booking.totalAmount,
                                                ),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Reject claim'),
                                      ),
                                    ],
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
                                      style: GoogleFonts.outfit(
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

class _ClaimNoteDialog extends StatefulWidget {
  const _ClaimNoteDialog({required this.title, required this.visibility});

  final String title;
  final String visibility;

  @override
  State<_ClaimNoteDialog> createState() => _ClaimNoteDialogState();
}

class _ClaimNoteDialogState extends State<_ClaimNoteDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.visibility == 'INTERNAL'
                      ? 'Internal Admin note'
                      : 'Customer-visible explanation',
                  hintText: 'Explain the next step or decision',
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.length < 3) {
                setState(
                    () => _validationError = 'Enter at least 3 characters.');
                return;
              }
              Navigator.pop(context, text);
            },
            child: const Text('Save'),
          ),
        ],
      );
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
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
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
