import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/widgets/primary_action_button.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(Map<String, dynamic> args) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(
            channel: args['channel'] as String,
            identifier: args['identifier'] as String,
            otp: _otpController.text.trim(),
            role: args['role'] as String,
            name: args['name'] as String?,
          );
      if (!mounted) return;
      context.go('/app');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to verify OTP: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (GoRouterState.of(context).extra as Map<String, dynamic>?) ??
        <String, dynamic>{
          'channel': 'PHONE',
          'identifier': '',
          'role': 'CUSTOMER',
          'name': null,
        };

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the verification code sent to ${args['identifier']}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This keeps sign-in secure while staying fast for customers and workers.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 4) {
                    return 'Enter the OTP';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: _isLoading ? 'Verifying...' : 'Verify and Continue',
                onPressed: _isLoading ? null : () => _verifyOtp(args),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
