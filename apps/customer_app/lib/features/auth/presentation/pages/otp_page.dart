import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  static const int _otpLength = 6;
  static const int _resendSeconds = 60;

  static const _accentColor = AbzioTheme.accentColor;
  static const _errorColor = Color(0xFFD24B4B);

  // 6 controllers + focus nodes for the digit boxes
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  int _resendCountdown = _resendSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    for (int i = 0; i < _otpLength; i++) {
      _focusNodes[i].addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        t.cancel();
        setState(() => _resendCountdown = 0);
        return;
      }
      setState(() => _resendCountdown -= 1);
    });
  }

  String get _otp =>
      _controllers.map((c) => c.text).join();

  bool get _isOtpComplete => _otp.length == _otpLength;

  String _friendlyError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Server took too long to respond. Please try again.';
      }
      return error.message ?? 'Network request failed. Please try again.';
    }
    if (error is FirebaseAuthException) {
      return error.message ?? 'Firebase verification failed. Please try again.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _onDigitChanged(int index, String value, Map<String, dynamic> args) {
    // Clear error on type
    if (_hasError) setState(() => _hasError = false);

    if (value.length == 1) {
      // Move focus to next box
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _resendOtp(Map<String, dynamic> args) async {
    if (_resendCountdown > 0) return;
    // Clear all boxes
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    try {
      final firebaseApp = await initializeFirebaseIfConfigured(
        ref.read(environmentProvider),
      );
      if (firebaseApp == null) throw StateError('Firebase not configured');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: args['identifier'] as String? ?? '',
        verificationCompleted: (credential) async {
          await _finishSignIn(credential, args);
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = true;
              _errorMessage = e.message ?? 'Failed to resend OTP';
            });
          }
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            // Update verificationId in args (in-memory only)
            args['verificationId'] = verificationId;
            setState(() => _isLoading = false);
            _startResendTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP resent successfully')),
            );
            _focusNodes[0].requestFocus();
          }
        },
        codeAutoRetrievalTimeout: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Unable to resend OTP: $e';
        });
      }
    }
  }

  Future<void> _verifyOtp(Map<String, dynamic> args) async {
    if (!_isOtpComplete) return;
    final verificationId = args['verificationId'] as String? ?? '';
    if (verificationId.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Session expired. Please go back and try again.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: _otp,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) {
        throw StateError('Firebase did not return a sign-in token');
      }
      await ref.read(authControllerProvider.notifier).signInWithFirebasePhone(
            idToken: idToken,
            name: args['name'] as String?,
          );
      if (!mounted) return;
      context.go('/app');
    } catch (e) {
      if (!mounted) return;
      final message = e is FirebaseAuthException &&
              (e.code == 'invalid-verification-code' ||
                  e.code == 'invalid-verification-id')
          ? 'Incorrect code. Please try again.'
          : _friendlyError(e);
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });
      if (message.startsWith('Incorrect code')) {
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      }
    }
  }

  Future<void> _finishSignIn(
    PhoneAuthCredential credential,
    Map<String, dynamic> args,
  ) async {
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCred.user?.getIdToken();
    if (idToken == null) {
      throw StateError('Firebase did not return a sign-in token');
    }
    await ref.read(authControllerProvider.notifier).signInWithFirebasePhone(
          idToken: idToken,
          name: args['name'] as String?,
        );
    if (mounted) context.go('/app');
  }

  @override
  Widget build(BuildContext context) {
    final args =
        (GoRouterState.of(context).extra as Map<String, dynamic>?) ??
            <String, dynamic>{
              'identifier': '',
              'name': null,
              'verificationId': '',
            };

    final rawPhone = args['identifier'] as String? ?? '';
    // Format: +91 XXXXX XXXXX
    final formattedPhone = rawPhone.startsWith('+91')
        ? '+91 ${rawPhone.substring(3)}'
        : rawPhone;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Custom AppBar ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => context.pop(),
                    color: AbzioTheme.lightTextPrimary,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).viewInsets.bottom + 32,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── Icon ───────────────────────────────────
                        Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.sms_rounded,
                              size: 34,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ─── Title ─────────────────────────────────
                        Text(
                          'Enter verification code',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AbzioTheme.lightTextPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            text: 'We sent a 6-digit code to\n',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AbzioTheme.lightTextSecondary,
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(
                                text: formattedPhone,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AbzioTheme.lightTextPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ─── 6-Box OTP Input ────────────────────────
                        _OtpBoxRow(
                          controllers: _controllers,
                          focusNodes: _focusNodes,
                          hasError: _hasError,
                          isLoading: _isLoading,
                          onChanged: (index, value) =>
                              _onDigitChanged(index, value, args),
                          onKeyEvent: _onKeyEvent,
                        ),

                        // ─── Error message ─────────────────────────
                        if (_hasError) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 15, color: _errorColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _errorMessage,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _errorColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 28),

                        // ─── Verify button ─────────────────────────
                        TapScale(
                          onTap: (_isOtpComplete && !_isLoading)
                              ? () => _verifyOtp(args)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              color: (_isOtpComplete && !_isLoading)
                                  ? const Color(0xFF111111)
                                  : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Verify & Continue',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: (_isOtpComplete && !_isLoading)
                                          ? Colors.white
                                          : const Color(0xFFAAAAAA),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // ─── Resend ─────────────────────────────────
                        Center(
                          child: _resendCountdown > 0
                              ? Text(
                                  'Resend OTP in ${_resendCountdown}s',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    color: AbzioTheme.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () => _resendOtp(args),
                                  child: Text(
                                    'Resend OTP',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: _accentColor,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _accentColor,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// 6-box OTP row
// ──────────────────────────────────────────────────────────────────────────────

class _OtpBoxRow extends StatelessWidget {
  const _OtpBoxRow({
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.isLoading,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final bool isLoading;
  final void Function(int index, String value) onChanged;
  final void Function(int index, KeyEvent event) onKeyEvent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final isFocused = focusNodes[i].hasFocus;
        final hasDigit = controllers[i].text.isNotEmpty;
        return KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) => onKeyEvent(i, event),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 46,
            height: 58,
            decoration: BoxDecoration(
              color: hasDigit
                  ? AbzioTheme.accentColor.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFD24B4B)
                    : isFocused
                        ? AbzioTheme.accentColor
                        : hasDigit
                            ? AbzioTheme.accentColor.withValues(alpha: 0.4)
                            : AbzioTheme.lightBorder,
                width: isFocused ? 1.8 : 1.2,
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: AbzioTheme.accentColor.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: controllers[i],
              focusNode: focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              enabled: !isLoading,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AbzioTheme.lightTextPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) => onChanged(i, value),
            ),
          ),
        );
      }),
    );
  }
}
