import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_execution_provider.dart';
import 'job_error_banner.dart';

class JobArrivalOtpStep extends ConsumerWidget {
  const JobArrivalOtpStep({
    super.key,
    required this.state,
    required this.controller,
    required this.onShowSnackBar,
  });

  final JobExecutionState state;
  final TextEditingController controller;
  final Function(String) onShowSnackBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = state.errorFor(JobExecutionStep.arrivalOtp);
    final notifier = ref.read(jobExecutionProvider.notifier);
    final isExpired = error?.kind == JobExecutionErrorKind.otpExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
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
          JobErrorBanner(error: error),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isLoading(JobExecutionStep.arrivalOtp)
                    ? null
                    : () async {
                        final code = controller.text.trim();
                        if (code.length != 4) {
                          onShowSnackBar('Enter the 4-digit code the customer shared.');
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
                        controller.clear();
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
}
