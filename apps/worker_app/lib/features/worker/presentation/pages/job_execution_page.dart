import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/job_execution_provider.dart';

class JobExecutionPage extends ConsumerStatefulWidget {
  const JobExecutionPage({
    super.key,
    required this.booking,
  });

  final JobExecutionBooking booking;

  @override
  ConsumerState<JobExecutionPage> createState() => _JobExecutionPageState();
}

class _JobExecutionPageState extends ConsumerState<JobExecutionPage> {
  final TextEditingController _arrivalOtpController = TextEditingController();
  final TextEditingController _completionOtpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(jobExecutionProvider.notifier).start(widget.booking);
    });
  }

  @override
  void dispose() {
    _arrivalOtpController.dispose();
    _completionOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobExecutionProvider);

    if (!state.hasBooking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job execution')),
        body: const Center(
          child: PremiumEmptyState(
            icon: Icons.assignment_late_rounded,
            title: 'Missing job details',
            subtitle: 'Open this flow from an accepted job in the Jobs tab.',
          ),
        ),
      );
    }

    final booking = state.booking!;
    final progress = state.currentStep.clamp(1, 7) / 7;
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
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 52,
                          width: 52,
                          decoration: BoxDecoration(
                            color: booking.accentColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.assignment_rounded,
                            color: booking.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.serviceName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${booking.customerName} • ${booking.locationLabel}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      booking.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PremiumStatCard(
                            label: 'Progress',
                            value: '${state.currentStep.clamp(1, 7)} of 7',
                            icon: Icons.route_rounded,
                            accentColor: booking.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PremiumStatCard(
                            label: 'Payout',
                            value: booking.earningsLabel,
                            icon: Icons.payments_rounded,
                            accentColor: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      completed
                          ? 'Flow complete'
                          : 'Step ${state.currentStep.clamp(1, 7)} of 7',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: booking.accentColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _StepCard(
              stepNumber: 1,
              title: 'Mark arrived',
              subtitle: 'Capture your GPS and notify the customer that you are on site.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 1,
              isCompleted: state.currentStep > 1 || state.summary != null,
              child: _buildArrivalStep(context, state),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 2,
              title: 'Enter arrival code',
              subtitle: 'Ask the customer for their code and verify it here.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 2,
              isCompleted: state.currentStep > 2 || state.summary != null,
              child: _buildArrivalOtpStep(context, state),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 3,
              title: 'Before photos',
              subtitle: 'Upload 1 to 5 photos before starting the work.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 3,
              isCompleted: state.currentStep > 3 || state.summary != null,
              child: _buildPhotoStep(context, state, JobExecutionPhotoType.before),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 4,
              title: 'Checklist',
              subtitle: 'Complete the service checklist in order.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 4,
              isCompleted: state.currentStep > 4 || state.summary != null,
              child: _buildChecklistStep(context, state),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 5,
              title: 'After photos',
              subtitle: 'Capture the finished work after the checklist is done.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 5,
              isCompleted: state.currentStep > 5 || state.summary != null,
              child: _buildPhotoStep(context, state, JobExecutionPhotoType.after),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 6,
              title: 'Request completion code',
              subtitle: 'Ask the customer to share the final code.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 6,
              isCompleted: state.currentStep > 6 || state.summary != null,
              child: _buildCompletionRequestStep(context, state),
            ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 7,
              title: 'Finish job',
              subtitle: 'Verify the final code and show the payout summary.',
              accentColor: booking.accentColor,
              isActive: state.currentStep == 7,
              isCompleted: state.summary != null,
              child: _buildFinalStep(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalStep(BuildContext context, JobExecutionState state) {
    final error = state.errorFor(JobExecutionStep.arrival);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final locationLabel = state.currentPosition == null
        ? 'Location will be captured when you mark arrival.'
        : 'GPS captured at ${state.currentPosition!.latitude.toStringAsFixed(5)}, ${state.currentPosition!.longitude.toStringAsFixed(5)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locationLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.isLoading(JobExecutionStep.arrival))
          const LinearProgressIndicator(minHeight: 4),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.arrival)
                    ? null
                    : () async {
                        await notifier.markArrived();
                        if (ref.read(jobExecutionProvider).errorFor(JobExecutionStep.arrival) == null) {
                          _showSnackBar('Ask the customer for their code.');
                        }
                      },
                child: const Text('Mark arrived'),
              ),
            ),
            if (error?.kind == JobExecutionErrorKind.location) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text('Open settings'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ask the customer for their code after you mark arrived. It is not shown in this app.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildArrivalOtpStep(BuildContext context, JobExecutionState state) {
    final error = state.errorFor(JobExecutionStep.arrivalOtp);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final isExpired = error?.kind == JobExecutionErrorKind.otpExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _arrivalOtpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: '4-digit arrival code',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.arrivalOtp)
                    ? null
                    : () async {
                        final code = _arrivalOtpController.text.trim();
                        if (code.length != 4) {
                          _showSnackBar('Enter the 4-digit code the customer shared.');
                          return;
                        }
                        await notifier.verifyArrivalOtp(code);
                      },
                child: state.isLoading(JobExecutionStep.arrivalOtp)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify arrival code'),
              ),
            ),
            if (isExpired) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: state.isLoading(JobExecutionStep.arrivalOtp)
                    ? null
                    : () async {
                        await notifier.markArrived();
                        _arrivalOtpController.clear();
                      },
                child: const Text('Mark arrived again'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Invalid codes stay inline. If the code expired, mark arrived again to generate a fresh one.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildPhotoStep(
    BuildContext context,
    JobExecutionState state,
    JobExecutionPhotoType type,
  ) {
    final isBefore = type == JobExecutionPhotoType.before;
    final items = isBefore ? state.beforePhotos : state.afterPhotos;
    final step = isBefore ? JobExecutionStep.beforePhotos : JobExecutionStep.afterPhotos;
    final error = state.errorFor(step);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final canUpload = isBefore || state.allRequiredChecklistComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canUpload && !isBefore)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Finish the checklist before uploading after photos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!canUpload && !isBefore) const SizedBox(height: 12),
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.isLoading(step)) ...[
          const LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (!canUpload || state.isLoading(step))
              ? null
              : () async {
                  await notifier.pickAndUploadPhotos(type);
                },
          icon: Icon(isBefore ? Icons.camera_alt_rounded : Icons.photo_library_rounded),
          label: Text(isBefore ? 'Add before photos' : 'Add after photos'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          PremiumEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No ${isBefore ? 'before' : 'after'} photos yet',
            subtitle: 'Add up to five photos to document this step.',
          )
        else
          Column(
            children: items
                .map(
                  (draft) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PhotoDraftTile(
                      draft: draft,
                      onRetry: draft.hasFailed
                          ? () async {
                              await notifier.retryPhoto(type, draft.id);
                            }
                          : null,
                      accentColor: widget.booking.accentColor,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildChecklistStep(BuildContext context, JobExecutionState state) {
    final error = state.errorFor(JobExecutionStep.checklist);
    final notifier = ref.read(jobExecutionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!state.checklistLoaded) ...[
          if (state.isLoading(JobExecutionStep.checklist))
            const LinearProgressIndicator(minHeight: 4)
          else
            FilledButton.icon(
              onPressed: () async {
                await notifier.loadChecklistTemplate();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Load checklist'),
            ),
          const SizedBox(height: 12),
        ],
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (state.checklistItems.isNotEmpty)
          ...state.checklistItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.completed
                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: CheckboxListTile(
                  value: item.completed,
                  onChanged: state.isLoading(JobExecutionStep.checklist)
                      ? null
                      : (value) async {
                          await notifier.toggleChecklistItem(item.id, value ?? false);
                        },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (item.requiresPhoto)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.photo_camera_outlined, size: 18),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    item.required ? 'Required' : 'Optional',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ),
          )
        else
          const PremiumEmptyState(
            icon: Icons.fact_check_outlined,
            title: 'No checklist items loaded',
            subtitle: 'The service checklist template will appear here once it loads.',
          ),
        const SizedBox(height: 10),
        Text(
          state.allRequiredChecklistComplete
              ? 'Checklist complete. You can move to after photos.'
              : 'Complete every required item to unlock after photos.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: state.allRequiredChecklistComplete
                    ? const Color(0xFF0F766E)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildCompletionRequestStep(BuildContext context, JobExecutionState state) {
    final error = state.errorFor(JobExecutionStep.completionRequest);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final blocker = state.completionBlocker;
    final ready = state.canRequestCompletionOtp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        if (blocker != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocker.message,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (blocker.missingPhotos)
                  Text(
                    'Missing photos: after photos are still required.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (blocker.missingItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Missing items:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  ...blocker.missingItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('• $item'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: (!ready || state.isLoading(JobExecutionStep.completionRequest))
              ? null
              : () async {
                  await notifier.requestCompletionOtp();
                },
          icon: const Icon(Icons.key_rounded),
          label: state.isLoading(JobExecutionStep.completionRequest)
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Request completion code'),
        ),
        const SizedBox(height: 10),
        Text(
          ready
              ? 'The customer can now share the final completion code.'
              : 'Finish the checklist and after photos before requesting the final code.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildFinalStep(BuildContext context, JobExecutionState state) {
    final error = state.errorFor(JobExecutionStep.completionOtp);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final summary = state.summary;
    final isExpired = error?.kind == JobExecutionErrorKind.otpExpired;

    if (summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PremiumStatCard(
                  label: 'Earnings',
                  value: summary.earningsLabel,
                  icon: Icons.payments_rounded,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Completed',
                  value: summary.completedAtLabel,
                  icon: Icons.verified_rounded,
                  accentColor: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.go('/jobs?tab=completed'),
            child: const Text('Back to completed jobs'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _completionOtpController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            labelText: '4-digit completion code',
            counterText: '',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (error != null) ...[
          _ErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.completionOtp)
                    ? null
                    : () async {
                        final code = _completionOtpController.text.trim();
                        if (code.length != 4) {
                          _showSnackBar('Enter the 4-digit completion code.');
                          return;
                        }
                        await notifier.verifyCompletionOtp(code);
                      },
                child: state.isLoading(JobExecutionStep.completionOtp)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify completion code'),
              ),
            ),
            if (isExpired) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: state.isLoading(JobExecutionStep.completionOtp)
                    ? null
                    : () async {
                        await notifier.requestCompletionOtp();
                      },
                child: const Text('Request new code'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'After verification, the job moves to completed and the earnings summary appears here.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.isActive,
    required this.isCompleted,
    required this.child,
  });

  final int stepNumber;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool isActive;
  final bool isCompleted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF10B981).withValues(alpha: 0.2)
              : isActive
                  ? accentColor.withValues(alpha: 0.32)
                  : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : isActive
                              ? accentColor.withValues(alpha: 0.12)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 20)
                          : Text(
                              stepNumber.toString(),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: isActive ? accentColor : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.error,
  });

  final JobExecutionStepError error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        error.message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PhotoDraftTile extends StatelessWidget {
  const _PhotoDraftTile({
    required this.draft,
    required this.onRetry,
    required this.accentColor,
  });

  final JobExecutionPhotoDraft draft;
  final VoidCallback? onRetry;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: draft.hasFailed
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.2)
              : accentColor.withValues(alpha: 0.16),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 52,
            width: 52,
            child: Image.file(
              File(draft.file.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          draft.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          draft.hasFailed
              ? draft.errorMessage ?? 'Upload failed'
              : draft.isUploaded
                  ? 'Uploaded successfully'
                  : draft.uploading
                      ? 'Uploading...'
                      : 'Waiting to upload',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: onRetry != null
            ? TextButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              )
            : draft.isUploaded
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                : draft.uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.pending_outlined),
      ),
    );
  }
}
