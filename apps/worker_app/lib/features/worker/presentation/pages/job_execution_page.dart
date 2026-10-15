import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/job_execution_provider.dart';
import 'generate_quote_page.dart';
import 'add_spare_parts_page.dart';
import '../widgets/job_header_card.dart';
import '../widgets/job_step_card.dart';
import '../widgets/job_arrival_step.dart';
import '../widgets/job_arrival_otp_step.dart';
import '../widgets/job_photo_step.dart';
import '../widgets/job_checklist_step.dart';
import '../widgets/job_completion_request_step.dart';
import '../widgets/job_final_step.dart';

class JobExecutionPage extends ConsumerStatefulWidget {
  const JobExecutionPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  ConsumerState<JobExecutionPage> createState() => _JobExecutionPageState();
}

class _JobExecutionPageState extends ConsumerState<JobExecutionPage> {
  final TextEditingController _arrivalOtpController = TextEditingController();
  final TextEditingController _completionOtpController =
      TextEditingController();
  bool _loadingBooking = true;
  bool _bookingLoadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveBooking();
    });
  }

  Future<void> _resolveBooking() async {
    if (widget.bookingId.trim().isEmpty) {
      if (mounted) setState(() => _loadingBooking = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loadingBooking = true;
        _bookingLoadFailed = false;
      });
    }
    try {
      final booking =
          await ref.read(jobExecutionBookingProvider(widget.bookingId).future);
      if (!mounted) {
        return;
      }
      if (booking == null) {
        setState(() {
          _loadingBooking = false;
        });
        return;
      }

      ref.read(jobExecutionProvider.notifier).start(booking);
      setState(() {
        _loadingBooking = false;
        _bookingLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBooking = false;
        _bookingLoadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _arrivalOtpController.dispose();
    _completionOtpController.dispose();
    super.dispose();
  }

  Future<void> _openNavigation(String destinationQuery) async {
    final booking = ref.read(jobExecutionProvider).booking;
    final lat = booking?.destinationLatitude;
    final lng = booking?.destinationLongitude;
    final query = destinationQuery.trim();
    if (lat != null && lng != null) {
      final uri = Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': 'Current+Location',
        'destination': '$lat,$lng',
        'travelmode': 'driving',
        'dir_action': 'navigate',
      });
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnackBar('Could not open Google Maps.');
      }
      return;
    }

    if (query.isEmpty) {
      _showSnackBar('No destination available for this job.');
      return;
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': 'Current+Location',
      'destination': query,
      'travelmode': 'driving',
      'dir_action': 'navigate',
    });
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      _showSnackBar('Could not open Google Maps.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobExecutionProvider);
    final hasCurrentBooking = state.booking?.bookingId == widget.bookingId;

    if (!hasCurrentBooking) {
      if (_loadingBooking) {
        return Scaffold(
          appBar: AppBar(title: const Text('Job execution')),
          body: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Job execution')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _bookingLoadFailed
                      ? Icons.cloud_off_rounded
                      : Icons.assignment_late_rounded,
                  size: 42,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 14),
                Text(
                  _bookingLoadFailed
                      ? 'Could not load this job'
                      : 'Job details unavailable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  _bookingLoadFailed
                      ? 'Check your connection and try again.'
                      : 'This job may no longer be assigned to you. Open it from the Jobs tab.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (_bookingLoadFailed) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadingBooking
                        ? null
                        : () {
                            ref.invalidate(workerJobsProvider('accepted'));
                            ref.invalidate(workerJobsProvider('active'));
                            ref.invalidate(workerDashboardStatsProvider);
                            ref.invalidate(
                              jobExecutionBookingProvider(widget.bookingId),
                            );
                            _resolveBooking();
                          },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final booking = state.booking!;
    final completed = state.summary != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Job ${booking.bookingCode}'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            if (booking.isMaintenanceVisit) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.event_repeat_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Recurring maintenance visit · follow the scheduled job details.')),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            JobHeaderCard(
              state: state,
              accentColor: booking.accentColor,
            ),
            const SizedBox(height: 16),
            _PartnerClaimCard(bookingId: booking.bookingId),
            BookingDiagnosticPhotosSection(bookingId: booking.bookingId),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final supportUri = Uri(
                  path: '/support',
                  queryParameters: {
                    'category': 'other',
                    'autoFocusForm': 'true',
                    'subject': 'Help with job ${booking.bookingCode}',
                    'message': 'I need help with job #${booking.bookingCode} for '
                        '${booking.serviceName} (step ${state.currentStep} of 7). '
                        'Please help me with: ',
                  },
                );
                context.push(supportUri.toString());
              },
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Get help with this job'),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 1,
              title: 'Mark arrived',
              subtitle:
                  'Capture your GPS and notify the customer that you are on site.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 1,
              isCompleted: state.currentStep > 1 || state.summary != null,
              child: JobArrivalStep(
                state: state,
                onNavigate: () => _openNavigation(booking.destinationQuery),
                onShowSnackBar: _showSnackBar,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 2,
              title: 'Enter arrival code',
              subtitle: 'Ask the customer for their code and verify it here.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 2,
              isCompleted: state.currentStep > 2 || state.summary != null,
              child: JobArrivalOtpStep(
                state: state,
                controller: _arrivalOtpController,
                onShowSnackBar: _showSnackBar,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 3,
              title: 'Before photos',
              subtitle: 'Upload 1 to 5 photos before starting the work.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 3,
              isCompleted: state.currentStep > 3 || state.summary != null,
              child: JobPhotoStep(
                state: state,
                type: JobExecutionPhotoType.before,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 4,
              title: 'Checklist',
              subtitle: 'Complete the service checklist in order.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 4,
              isCompleted: state.currentStep > 4 || state.summary != null,
              child: JobChecklistStep(
                state: state,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 5,
              title: 'After photos',
              subtitle:
                  'Capture the finished work after the checklist is done.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 5,
              isCompleted: state.currentStep > 5 || state.summary != null,
              child: JobPhotoStep(
                state: state,
                type: JobExecutionPhotoType.after,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 6,
              title: 'Request completion code',
              subtitle: 'Ask the customer to share the final code.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 6,
              isCompleted: state.currentStep > 6 || state.summary != null,
              child: JobCompletionRequestStep(
                state: state,
              ),
            ),
            const SizedBox(height: 12),
            JobStepCard(
              stepNumber: 7,
              title: 'Finish job',
              subtitle: 'Verify the final code and show the payout summary.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 7,
              isCompleted: state.summary != null,
              child: JobFinalStep(
                state: state,
                controller: _completionOtpController,
                onShowSnackBar: _showSnackBar,
              ),
            ),

            // ── Generate Quote button (site-visit / large jobs) ──────────────
            if (!completed) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final sent = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            GenerateQuotePage(bookingId: widget.bookingId),
                      ),
                    );
                    if (sent == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Quote sent! Waiting for customer approval.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.request_quote_rounded),
                  label: const Text('Generate Site Visit Quote'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final sent = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddSparePartsPage(bookingId: widget.bookingId),
                      ),
                    );
                    if (sent == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Spare parts sent! Waiting for customer payment.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.hardware_rounded),
                  label: const Text('Add Spare Parts'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PartnerClaimCard extends ConsumerStatefulWidget {
  const _PartnerClaimCard({required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<_PartnerClaimCard> createState() => _PartnerClaimCardState();
}

class _PartnerClaimCardState extends ConsumerState<_PartnerClaimCard> {
  late Future<Map<String, dynamic>?> _claim;
  Map<String, dynamic>? _lastLoadedClaim;
  int _loadGeneration = 0;
  final _response = TextEditingController();
  bool _sending = false;
  String? _responseKey;
  String? _responseKeyMessage;
  String? _correctiveWorkKey;
  String? _proposalKey;
  String? _proposalKeyForTimestamp;

  @override
  void initState() {
    super.initState();
    _claim = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final generation = ++_loadGeneration;
    late final Map<String, dynamic> response;
    try {
      response = await ref
          .read(apiClientProvider)
          .get('/worker/bookings/${widget.bookingId}/dispute');
    } catch (_) {
      if (!mounted) return _lastLoadedClaim;
      rethrow;
    }
    if (!mounted) return _lastLoadedClaim;
    final raw = response['dispute'];
    final claim = raw is Map ? Map<String, dynamic>.from(raw) : null;
    if (generation != _loadGeneration) return _lastLoadedClaim;
    _lastLoadedClaim = claim;
    return claim;
  }

  String _formatWhen(Object? raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    return parsed == null
        ? 'time pending'
        : DateFormat('d MMM y, h:mm a').format(parsed.toLocal());
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _response.text.trim();
    if (message.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a response before sending.'),
      ));
      return;
    }
    setState(() => _sending = true);
    if (_responseKeyMessage != message) _responseKey = null;
    final key = _responseKey ??
        'partner-claim-message-${widget.bookingId}-${DateTime.now().microsecondsSinceEpoch}';
    _responseKey = key;
    _responseKeyMessage = message;
    var postSucceeded = false;
    try {
      await ref.read(apiClientProvider).post(
          '/bookings/${widget.bookingId}/dispute/message',
          data: {'message': message, 'idempotencyKey': key});
      postSucceeded = true;
      if (!mounted) return;
      final refresh = _load();
      setState(() => _claim = refresh);
      await refresh;
      if (!mounted) return;
      if (_response.text.trim() == message) _response.clear();
      _responseKey = null;
      _responseKeyMessage = null;
    } catch (error) {
      if (mounted) {
        final networkFailure = error is DioException &&
            const {
              DioExceptionType.connectionError,
              DioExceptionType.connectionTimeout,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(error.type);
        if (networkFailure && !postSucceeded) {
          setState(() => _claim = _load());
        } else if (!postSucceeded) {
          _responseKey = null;
          _responseKeyMessage = null;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(postSucceeded
              ? 'Your response was sent, but the latest claim status could not be loaded. Refresh before trying again.'
              : networkFailure
                  ? 'Connection was interrupted. Refresh the claim before retrying; your response may already have reached the server.'
                  : 'Could not send your response. Please retry.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _proposeAppointment() async {
    if (_sending) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (!mounted || _sending || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 2))),
    );
    if (!mounted || _sending || time == null) return;
    final proposedAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!proposedAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a time in the future.')),
      );
      return;
    }
    setState(() => _sending = true);
    final proposalTimestamp = proposedAt.toUtc().toIso8601String();
    if (_proposalKeyForTimestamp != proposalTimestamp) {
      _proposalKey = null;
      _proposalKeyForTimestamp = proposalTimestamp;
    }
    final proposalKey = _proposalKey ??=
        'partner-claim-proposal-${widget.bookingId}-${proposedAt.millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch}';
    var postSucceeded = false;
    try {
      await ref.read(apiClientProvider).post(
        '/worker/bookings/${widget.bookingId}/dispute/rework/propose',
        data: {
          'proposedAt': proposalTimestamp,
          'message': 'I can attend at the proposed time.',
          'idempotencyKey': proposalKey,
        },
      );
      postSucceeded = true;
      if (!mounted) return;
      final refresh = _load();
      setState(() => _claim = refresh);
      await refresh;
      if (!mounted) return;
      _proposalKey = null;
      _proposalKeyForTimestamp = null;
    } catch (error) {
      if (mounted) {
        final statusCode =
            error is DioException ? error.response?.statusCode : null;
        final slotConflict = statusCode == 409 || statusCode == 422;
        final networkFailure = error is DioException &&
            const {
              DioExceptionType.connectionError,
              DioExceptionType.connectionTimeout,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(error.type);
        if (networkFailure && !postSucceeded) {
          setState(() => _claim = _load());
        } else if (!postSucceeded && slotConflict) {
          _proposalKey = null;
          _proposalKeyForTimestamp = null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              postSucceeded
                  ? 'Your appointment proposal was sent, but the latest claim status could not be loaded. Refresh before retrying.'
                  : networkFailure
                      ? 'Connection was interrupted. Refresh the claim before retrying; your request may already have reached the server.'
                      : slotConflict
                          ? 'That time is unavailable. Choose another appointment time.'
                          : 'Could not send the appointment proposal. Refresh the claim and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _completeCorrectiveWork() async {
    if (_sending) return;
    setState(() => _sending = true);
    var postSucceeded = false;
    try {
      await ref.read(apiClientProvider).post(
        '/worker/bookings/${widget.bookingId}/dispute/rework/complete',
        data: {
          'message': 'Approved corrective work was completed.',
          'idempotencyKey': _correctiveWorkKey ??=
              'partner-claim-complete-${widget.bookingId}-${DateTime.now().microsecondsSinceEpoch}',
        },
      );
      postSucceeded = true;
      if (!mounted) return;
      final refresh = _load();
      setState(() => _claim = refresh);
      await refresh;
      if (!mounted) return;
      _correctiveWorkKey = null;
    } catch (error) {
      if (mounted) {
        final networkFailure = error is DioException &&
            const {
              DioExceptionType.connectionError,
              DioExceptionType.connectionTimeout,
              DioExceptionType.sendTimeout,
              DioExceptionType.receiveTimeout,
            }.contains(error.type);
        if (networkFailure && !postSucceeded) {
          setState(() => _claim = _load());
        } else if (!postSucceeded) {
          _correctiveWorkKey = null;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              postSucceeded
                  ? 'Corrective work was recorded, but the latest claim status could not be loaded. Refresh before retrying.'
                  : networkFailure
                      ? 'Connection was interrupted. Refresh the claim before retrying; your request may already have reached the server.'
                      : 'Corrective work cannot be completed yet.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _claim,
        builder: (context, snapshot) {
          final reloading = snapshot.connectionState == ConnectionState.waiting;
          final claim =
              snapshot.hasError || reloading ? _lastLoadedClaim : snapshot.data;
          if (reloading && _lastLoadedClaim == null) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (claim == null) {
            if (!snapshot.hasError) return const SizedBox.shrink();
            final colors = Theme.of(context).colorScheme;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off_outlined, color: colors.error),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Could not load the customer claim.'),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _claim = _load();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final cs = Theme.of(context).colorScheme;
          final history =
              (claim['history'] as List? ?? const []).whereType<Map>().toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.hasError)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Could not refresh the claim. Showing the last saved details.',
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _claim = _load()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(18)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer service claim',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                          'Status: ${(claim['status'] as String? ?? 'open').replaceAll('_', ' ')}'),
                      if ((claim['referenceCode'] as String?)?.isNotEmpty ==
                          true)
                        Text('Reference: ${claim['referenceCode']}'),
                      const SizedBox(height: 8),
                      Text(claim['reason'] as String? ?? ''),
                      BookingDiagnosticPhotosSection(
                        bookingId: widget.bookingId,
                        photoIds:
                            (claim['evidencePhotoIds'] as List? ?? const [])
                                .whereType<String>()
                                .toList(growable: false),
                      ),
                      if ((claim['remedyStatus'] as String?) ==
                              'awaiting_admin_schedule' &&
                          claim['reworkProposedAt'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Appointment proposed: ${_formatWhen(claim['reworkProposedAt'])} · awaiting Admin confirmation',
                          ),
                        ),
                      if ((claim['remedyStatus'] as String?) == 'scheduled' &&
                          claim['reworkScheduledAt'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Corrective work scheduled: ${_formatWhen(claim['reworkScheduledAt'])}',
                          ),
                        ),
                      for (final event in history)
                        if (event['type'] == 'request_info' ||
                            event['type'] == 'customer_response')
                          Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  '${(event['type'] as String).replaceAll('_', ' ')}: ${event['message'] ?? ''}')),
                      if ([
                        'open',
                        'under_review',
                        'action_required',
                        'approved'
                      ].contains(claim['status'])) ...[
                        const SizedBox(height: 10),
                        TextField(
                            controller: _response,
                            maxLines: 3,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                                labelText: 'Your response to the claim')),
                        const SizedBox(height: 8),
                        Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                                onPressed: _sending || reloading ? null : _send,
                                icon: const Icon(Icons.reply_rounded),
                                label: Text(
                                    _sending ? 'Sending…' : 'Send response'))),
                      ],
                      if (claim['remedyStatus'] == 'awaiting_partner_proposal')
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _sending ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting
                                ? null
                                : _proposeAppointment,
                            icon: const Icon(Icons.event_available_outlined),
                            label: const Text(
                                'Propose corrective-work appointment'),
                          ),
                        ),
                      if (claim['remedyStatus'] == 'scheduled')
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _sending || reloading
                                ? null
                                : _completeCorrectiveWork,
                            icon: const Icon(Icons.task_alt_rounded),
                            label:
                                const Text('Report corrective work complete'),
                          ),
                        ),
                    ]),
              ),
            ],
          );
        },
      );
}
