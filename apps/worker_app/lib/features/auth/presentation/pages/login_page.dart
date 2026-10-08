import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/worker_logo.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorText;

  static const _background = VeeduFixDesignSystem.ivory;
  static const _ink = VeeduFixDesignSystem.ink;
  static const _muted = VeeduFixDesignSystem.mutedInk;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onFocusChanged() => setState(() {});

  void _onPhoneChanged() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  bool get _isPhoneValid => _phoneController.text.trim().length == 10;
  String get _phone => '+91${_phoneController.text.trim()}';

  Future<void> _requestOtp() async {
    if (!_isPhoneValid) {
      setState(() => _errorText = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final firebaseApp = await initializeFirebaseIfConfigured(
        ref.read(environmentProvider),
      );
      if (firebaseApp == null) {
        throw StateError('Firebase is not configured for this build');
      }
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onTimeout,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = error is FirebaseAuthException
            ? (error.message ?? error.code)
            : 'Firebase setup error: $error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onVerificationCompleted(PhoneAuthCredential credential) async {
    try {
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw StateError('No Firebase sign-in token');
      await ref.read(authControllerProvider.notifier).signInWithFirebasePhone(
            idToken: idToken,
            role: 'WORKER',
          );
      if (mounted) context.go('/worker');
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'Sign-in failed. Please try again.');
      }
    }
  }

  void _onVerificationFailed(FirebaseAuthException error) {
    if (mounted) {
      setState(() => _errorText =
          error.message ?? 'Verification failed. Please try again.');
    }
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/otp', extra: <String, dynamic>{
      'identifier': _phone,
      'verificationId': verificationId,
      'resendToken': resendToken,
      'role': 'WORKER',
    });
  }

  void _onTimeout(String verificationId) {
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            VeeduFixDesignSystem.pageMargin,
            0,
            VeeduFixDesignSystem.pageMargin,
            24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Center(child: WorkerLogo(height: 38, color: _ink)),
                  const SizedBox(height: 32),
                  Text('Your work.\nYour growth.',
                      style: textTheme.displayMedium),
                  const SizedBox(height: 12),
                  Text(
                      'Accept trusted local jobs and grow your service business with Veedufix.',
                      style: textTheme.bodyLarge
                          ?.copyWith(color: _muted, height: 1.5)),
                  const SizedBox(height: 24),
                  const _TrustRow(),
                  const SizedBox(height: 24),
                  Text('MOBILE NUMBER',
                      style: textTheme.labelMedium?.copyWith(color: _muted)),
                  const SizedBox(height: 10),
                  VeeduFixPhoneField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    hasError: _errorText != null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onSubmitted: (_) => _requestOtp(),
                    trailing: _isPhoneValid
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AbzioTheme.successColor,
                          )
                        : null,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  VeeduFixButton(
                    label: 'Send OTP',
                    onPressed:
                        _isPhoneValid && !_isLoading ? _requestOtp : null,
                    isLoading: _isLoading,
                  ),
                  const Spacer(),
                  const SizedBox(height: 28),
                  Text(
                    'By continuing, you agree to the VeeduFix Partner Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _TrustItem(icon: Icons.location_on_outlined, label: 'Local jobs'),
        SizedBox(width: 12),
        _TrustItem(icon: Icons.schedule_rounded, label: 'Flexible hours'),
        SizedBox(width: 12),
        _TrustItem(icon: Icons.payments_outlined, label: 'Secure payouts'),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: VeeduFixDesignSystem.gold, size: 22),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
