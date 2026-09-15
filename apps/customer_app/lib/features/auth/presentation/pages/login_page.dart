import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/customer_logo.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierController = TextEditingController(text: '+91 ');
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final firebaseApp = await initializeFirebaseIfConfigured(
        ref.read(environmentProvider),
      );
      if (firebaseApp == null) {
        throw StateError('Firebase is not configured for this app build');
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onCodeAutoRetrievalTimeout,
      );
    } catch (error) {
      _showError('Unable to request OTP: $error');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _phoneNumber =>
      _identifierController.text.replaceAll(RegExp(r'\s+'), '');

  Future<void> _onVerificationCompleted(PhoneAuthCredential credential) async {
    await _finishFirebaseSignIn(credential);
  }

  void _onVerificationFailed(FirebaseAuthException error) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showError(error.message ?? 'Unable to send SMS verification code');
  }

  void _onCodeSent(String verificationId, int? forceResendingToken) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(
      '/otp',
      extra: <String, dynamic>{
        'identifier': _phoneNumber,
        'name': _nameController.text.trim(),
        'verificationId': verificationId,
      },
    );
  }

  void _onCodeAutoRetrievalTimeout(String verificationId) {
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _finishFirebaseSignIn(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw StateError('Firebase did not return a sign-in token');
      }

      await ref
          .read(authControllerProvider.notifier)
          .signInWithFirebasePhone(
            idToken: idToken,
            name: _nameController.text.trim(),
          );
      if (mounted) context.go('/app');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Unable to sign in: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 48),
                const CustomerLogo(height: 42),
                GradientHero(
                  title: 'Book trusted local experts.',
                  subtitle:
                      'Premium service booking for homeowners who want speed, trust, and real-time tracking.',
                  actionLabel: 'Continue',
                  action: _requestOtp,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        AbzioTheme.cardRadius,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trusted by local households',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Verified workers, secure payments, and smooth booking journeys.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in or create an account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use your mobile number and OTP to continue.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile number',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        validator: (value) {
                          final phone =
                              value?.replaceAll(RegExp(r'\s+'), '') ?? '';
                          if (phone.length < 10) {
                            return 'Enter a valid mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryActionButton(
                        label: _isLoading ? 'Sending OTP...' : 'Send OTP',
                        onPressed: _isLoading ? null : _requestOtp,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
