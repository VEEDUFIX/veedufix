import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/widgets/gradient_hero.dart';
import '../../../../core/widgets/primary_action_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierController = TextEditingController(text: '+91 ');
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: const String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '',
    ),
  );
  bool _isPhone = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authControllerProvider.notifier).requestOtp(
            channel: _isPhone ? 'PHONE' : 'EMAIL',
            identifier: _identifierController.text.trim(),
          );
      if (!mounted) return;
      final debugOtp = result['debugOtp'] as String?;
      if (debugOtp != null && debugOtp.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Development OTP: $debugOtp')),
        );
      }
      context.go('/otp', extra: {
        'channel': _isPhone ? 'PHONE' : 'EMAIL',
        'identifier': _identifierController.text.trim(),
        'role': 'CUSTOMER',
        'name': _nameController.text.trim(),
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to request OTP: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an identity token.');
      }
      await ref.read(authControllerProvider.notifier).signInWithGoogle(
            idToken: idToken,
            role: 'CUSTOMER',
          );
      if (!mounted) return;
      context.go('/app');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: GradientHero(
              title: 'Book trusted local experts.',
              subtitle:
                  'Premium service booking for homeowners who want speed, trust, and real-time tracking.',
              actionLabel: 'Continue',
              action: _requestOtp,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trusted by local households',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Verified workers, secure payments, and smooth booking journeys.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use mobile OTP, email, or Google to continue.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Phone')),
                          ButtonSegment(value: false, label: Text('Email')),
                        ],
                        selected: {_isPhone},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _isPhone = selection.first;
                            _identifierController.text =
                                _isPhone ? '+91 ' : '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _identifierController,
                        keyboardType:
                            _isPhone ? TextInputType.phone : TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: _isPhone ? 'Mobile number' : 'Email address',
                          prefixIcon: Icon(
                            _isPhone ? Icons.phone_rounded : Icons.email_rounded,
                          ),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Enter a valid ${_isPhone ? 'mobile number' : 'email address'}';
                          }
                          if (_isPhone && text.length < 10) {
                            return 'Enter a valid mobile number';
                          }
                          if (!_isPhone && !text.contains('@')) {
                            return 'Enter a valid email address';
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
                      const SizedBox(height: 16),
                      const SizedBox(height: 24),
                      PrimaryActionButton(
                        label: _isLoading ? 'Sending OTP...' : 'Send OTP',
                        onPressed: _isLoading ? null : _requestOtp,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata_rounded),
                        label: const Text('Continue with Google'),
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
