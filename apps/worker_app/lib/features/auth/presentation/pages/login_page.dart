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
  bool _isFocused = false;
  String? _errorText;

  static const _background = Color(0xFFFAFAF7);
  static const _ink = Color(0xFF171512);
  static const _muted = Color(0xFF77736D);
  static const _gold = Color(0xFFC6A769);
  static const _border = Color(0xFFE3DED4);

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onFocusChanged() => setState(() => _isFocused = _phoneFocusNode.hasFocus);

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
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) throw StateError('No Firebase sign-in token');
      await ref.read(authControllerProvider.notifier).signInWithFirebasePhone(
            idToken: idToken,
            role: 'WORKER',
          );
      if (mounted) context.go('/worker');
    } catch (_) {
      if (mounted) setState(() => _errorText = 'Sign-in failed. Please try again.');
    }
  }

  void _onVerificationFailed(FirebaseAuthException error) {
    if (mounted) setState(() => _errorText = error.message ?? 'Verification failed. Please try again.');
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/otp', extra: <String, dynamic>{
      'identifier': _phone,
      'verificationId': verificationId,
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
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),
                  const Center(child: WorkerLogo(height: 38, color: _ink)),
                  const SizedBox(height: 52),
                  Text('Your work.\nYour growth.', style: textTheme.displaySmall?.copyWith(color: _ink, fontWeight: FontWeight.w800, height: 1.05)),
                  const SizedBox(height: 14),
                  Text('Accept trusted local jobs and grow your service business with Veedufix.', style: textTheme.bodyLarge?.copyWith(color: _muted, height: 1.5)),
                  const SizedBox(height: 32),
                  const _TrustRow(),
                  const SizedBox(height: 40),
                  Text('MOBILE NUMBER', style: textTheme.labelSmall?.copyWith(color: _muted, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _errorText != null ? Colors.redAccent : (_isFocused ? _gold : _border), width: _isFocused ? 1.5 : 1)),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        const Text('+91', style: TextStyle(fontWeight: FontWeight.w700, color: _ink)),
                        Container(width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 12), color: _border),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            decoration: const InputDecoration(border: InputBorder.none, hintText: '98765 43210'),
                            onSubmitted: (_) => _requestOtp(),
                          ),
                        ),
                        if (_isPhoneValid) const Padding(padding: EdgeInsets.only(right: 14), child: Icon(Icons.check_circle_rounded, color: Colors.green)),
                      ],
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _requestOtp,
                      style: ElevatedButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send OTP', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 28),
                  const Text('By continuing, you agree to the Veedufix Partner Terms and Privacy Policy.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAAA59D), fontSize: 11, height: 1.5)),
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
          Icon(icon, color: const Color(0xFFC6A769), size: 22),
          const SizedBox(height: 7),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF77736D), fontSize: 11)),
        ],
      ),
    );
  }
}
