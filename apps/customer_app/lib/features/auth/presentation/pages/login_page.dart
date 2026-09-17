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
  bool _isFocused = false;
  String? _errorText;

  static const _bg = Color(0xFFFAFAF7);
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF888888);
  static const _border = Color(0xFFE4E4E4);
  static const _focusBorder = Color(0xFFC6A769);
  static const _errorColor = Color(0xFFCC4444);

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChange);
    _phoneController.addListener(_onPhoneChange);
  }

  void _onFocusChange() => setState(() => _isFocused = _phoneFocusNode.hasFocus);

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
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) throw StateError('No sign-in token');
      await ref.read(authControllerProvider.notifier).signInWithFirebasePhone(idToken: idToken);
      ref.read(guestModeProvider.notifier).state = false;
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorText = 'Sign-in failed. Please try again.'; });
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
    context.go('/otp', extra: <String, dynamic>{
      'identifier': _e164,
      'name': null,
      'verificationId': verificationId,
    });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
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
          padding: EdgeInsets.fromLTRB(28, 0, 28, bottomInset + 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),

                  // ─── Logo ────────────────────────────────────────
                  Center(
                    child: SizedBox(
                      height: 36,
                      child: CustomerLogo(
                        height: 36,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // ─── Headline ────────────────────────────────────
                  Text(
                    'Your home.\nHandled.',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                      height: 1.12,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Book trusted local professionals\nin just a few taps.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: _muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ─── Trust items ─────────────────────────────────
                  _TrustRow(),
                  const SizedBox(height: 40),

                  // ─── Phone label ─────────────────────────────────
                  Text(
                    'MOBILE NUMBER',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Phone input ─────────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _errorText != null
                            ? _errorColor
                            : _isFocused
                                ? _focusBorder
                                : _border,
                        width: _isFocused ? 1.5 : 1.0,
                      ),
                      boxShadow: _isFocused
                          ? [
                              BoxShadow(
                                color: _focusBorder.withValues(alpha: 0.12),
                                blurRadius: 0,
                                spreadRadius: 3,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Text(
                          '+91',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: _border,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            autofillHints: const [AutofillHints.telephoneNumber],
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                              letterSpacing: 0.5,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              hintText: '98765 43210',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFFBBBBBB),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            onSubmitted: (_) {
                              if (_isPhoneValid && !_isLoading) _sendOtp();
                            },
                          ),
                        ),
                        if (_isPhoneValid)
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ─── Inline error ────────────────────────────────
                  if (_errorText != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      _errorText!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ─── Send OTP button ─────────────────────────────
                  _PrimaryButton(
                    label: 'Send OTP',
                    isLoading: _isLoading,
                    enabled: _isPhoneValid && !_isLoading,
                    onTap: _sendOtp,
                  ),
                  const SizedBox(height: 14),

                  // ─── Skip ────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _skipForNow,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        child: Text(
                          'Skip for now',
                          style: GoogleFonts.inter(
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
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
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
                            ..onTap = () => _openUrl('https://veedufix.com/terms'),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            decoration: TextDecoration.underline,
                            color: Color(0xFF888888),
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl('https://veedufix.com/privacy'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
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
            color: Color(0xFFF0EBE1),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              size: 11,
              color: Color(0xFF8A6A20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF555555),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Primary CTA button
// ──────────────────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.enabled
        ? const Color(0xFF111111)
        : const Color(0xFFE0E0E0);
    final fg = widget.enabled ? Colors.white : const Color(0xFFAAAAAA);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 56,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (widget.enabled) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: fg,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
