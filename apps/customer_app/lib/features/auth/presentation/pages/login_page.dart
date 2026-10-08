import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/customer_logo.dart';
import '../../providers/guest_mode_provider.dart';

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

  static const _bg = AbzioTheme.lightBackground;
  static const _ink = AbzioTheme.lightTextPrimary;
  static const _muted = AbzioTheme.lightTextSecondary;
  static const _errorColor = AbzioTheme.dangerColor;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChange);
    _phoneController.addListener(_onPhoneChange);
  }

  void _onFocusChange() => setState(() {});

  void _onPhoneChange() {
    if (_errorText != null) setState(() => _errorText = null);
    setState(() {}); // rebuild to update button enabled state
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onFocusChange);
    _phoneController.removeListener(_onPhoneChange);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  bool get _isPhoneValid => _phoneController.text.length == 10;
  String get _e164 => '+91${_phoneController.text.trim()}';

  Future<void> _sendOtp() async {
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
        phoneNumber: _e164,
        verificationCompleted: _onVerificationCompleted,
        verificationFailed: _onVerificationFailed,
        codeSent: _onCodeSent,
        codeAutoRetrievalTimeout: _onTimeout,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Could not send OTP. Please try again.';
        });
      }
    }
  }

  Future<void> _onVerificationCompleted(PhoneAuthCredential credential) async {
    try {
      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) throw StateError('No sign-in token');
      await ref
          .read(authControllerProvider.notifier)
          .signInWithFirebasePhone(idToken: idToken);
      ref.read(guestModeProvider.notifier).state = false;
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = 'Sign-in failed. Please try again.';
        });
      }
    }
  }

  void _onVerificationFailed(FirebaseAuthException e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorText = e.message ?? 'Verification failed. Please try again.';
    });
  }

  void _onCodeSent(String verificationId, int? resendToken) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(
      '/otp',
      extra: <String, dynamic>{
        'identifier': _e164,
        'name': null,
        'verificationId': verificationId,
      },
    );
  }

  void _onTimeout(String verificationId) {
    if (mounted) setState(() => _isLoading = false);
  }

  void _skipForNow() {
    ref.read(guestModeProvider.notifier).state = true;
    context.go('/app');
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _bg,
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
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  bottomInset,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),

                  // ─── Logo ────────────────────────────────────────
                  const Center(
                    child: SizedBox(
                      height: 48,
                      child: CustomerLogo(height: 48, color: _ink),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── Headline ────────────────────────────────────
                  Text(
                    'Your home.\nHandled.',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Book trusted local professionals\nin just a few taps.',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ─── Trust items ─────────────────────────────────
                  const _TrustRow(),
                  const SizedBox(height: 24),

                  // ─── Phone label ─────────────────────────────────
                  Text(
                    'MOBILE NUMBER',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Phone input ─────────────────────────────────
                  VeeduFixPhoneField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    hasError: _errorText != null,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onSubmitted: (_) {
                      if (_isPhoneValid && !_isLoading) _sendOtp();
                    },
                    trailing: _isPhoneValid
                        ? const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AbzioTheme.successColor,
                          )
                        : null,
                  ),

                  // ─── Inline error ────────────────────────────────
                  if (_errorText != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      _errorText!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: _errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ─── Send OTP button ─────────────────────────────
                  VeeduFixButton(
                    label: 'Send OTP',
                    isLoading: _isLoading,
                    onPressed: _isPhoneValid && !_isLoading ? _sendOtp : null,
                  ),
                  const SizedBox(height: 14),

                  // ─── Skip ────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _skipForNow,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        child: Text(
                          'Skip for now',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                            decoration: TextDecoration.underline,
                            decorationColor: _muted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 24),

                  // ─── Legal ───────────────────────────────────────
                  Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFFAAAAAA),
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF888888),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _openUrl('https://veedufix.com/terms'),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF888888),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _openUrl('https://veedufix.com/privacy'),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Trust row — lightweight, integrated, not a card
// ──────────────────────────────────────────────────────────────────────────────

class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TrustItem(label: 'Verified professionals'),
        SizedBox(height: 8),
        _TrustItem(label: 'Real-time job updates'),
        SizedBox(height: 8),
        _TrustItem(label: 'Secure payments'),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: AbzioTheme.lightMuted,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              size: 11,
              color: AbzioTheme.accentColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AbzioTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
