import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/job_execution_provider.dart';
import '../providers/worker_availability_provider.dart';
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
      ref.read(locationBroadcasterProvider.notifier).start(booking.bookingId);
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
    // Stop location broadcasting when job page closes
    ref.read(locationBroadcasterProvider.notifier).stop();
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
            JobHeaderCard(
              state: state,
              accentColor: booking.accentColor,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final supportUri = Uri(
                  path: '/support',
                  queryParameters: {
                    'category': 'other',
                    'autoFocusForm': 'true',
                    'subject': 'Help with job ${booking.bookingCode}',
                    'message':
                        'I need help with job #${booking.bookingCode} for '
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
