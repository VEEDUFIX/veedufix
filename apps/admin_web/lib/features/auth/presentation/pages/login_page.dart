import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/admin_logo.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final GoogleSignIn _googleSignIn;
  StreamSubscription<GoogleSignInAccount?>? _authSubscription;
  bool _isSigningIn = false;
  bool _suppressNextSignOut = false;
  String? _initError;

  @override
  void initState() {
    super.initState();

    final environment = ref.read(environmentProvider);
    _googleSignIn = GoogleSignIn(
      clientId: environment.googleServerClientId.isEmpty
          ? null
          : environment.googleServerClientId,
      scopes: const ['email'],
    );

    _authSubscription = _googleSignIn.onCurrentUserChanged.listen(
      (account) => unawaited(_handleGoogleAccountChanged(account)),
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSigningIn = false;
          _initError = 'Google sign-in failed to initialize.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Google sign-in could not be started.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
    );

    if (environment.googleServerClientId.isEmpty) {
      _initError = 'Google sign-in is not configured for this environment.';
      return;
    }

    unawaited(
      _googleSignIn.signInSilently().catchError((Object error) {
        if (!mounted) {
          return null;
        }
        setState(() {
          _initError = 'Unable to initialize Google sign-in.';
        });
        return null;
      }),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  Future<void> _handleGoogleAccountChanged(GoogleSignInAccount? account) async {
    if (account == null) {
      if (_suppressNextSignOut) {
        _suppressNextSignOut = false;
        return;
      }

      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSigningIn = true;
      _initError = null;
    });

    try {
      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token.');
      }

      await ref.read(authControllerProvider.notifier).signInWithGoogle(
            idToken: idToken,
            role: 'ADMIN',
          );

      final session = ref.read(authControllerProvider).valueOrNull;
      if (session == null) {
        throw Exception('Admin session could not be created.');
      }

      if (session.user.role != 'ADMIN') {
        await ref.read(authControllerProvider.notifier).signOut();
        _suppressNextSignOut = true;
        await _googleSignIn.signOut();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('This Google account is not authorized for admin access.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      context.go('/admin');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _initError = 'Unable to complete Google sign-in.';
      });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to sign in right now.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );

      _suppressNextSignOut = true;
      await _googleSignIn.signOut();
      await ref.read(authControllerProvider.notifier).signOut();
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF064E3B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: Opacity(
                      opacity: 0.1,
                      child: GridPaper(
                        color: Colors.white,
                        interval: 40,
                        divisions: 2,
                        subdivisions: 1,
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield, color: Colors.white, size: 80),
                          const SizedBox(height: 24),
                          const AdminLogo(height: 64, color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Admin Control Center',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Secure access portal for managing platform operations, workers, and services.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFFF9FAFB),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        boxShadow: AbzioTheme.eliteShadow,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome Back',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: const Color(0xFF111827),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Sign in with your authorized admin account to continue.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                if (_initError != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _initError!,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                SizedBox(
                                  height: 52,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          ignoring: _isSigningIn || _initError != null,
                                          child: Opacity(
                                            opacity: _isSigningIn ? 0.35 : 1,
                                            child: (GoogleSignInPlatform.instance
                                                    as web.GoogleSignInPlugin)
                                                .renderButton(
                                              configuration: web.GSIButtonConfiguration(
                                                size: web.GSIButtonSize.large,
                                                text: web.GSIButtonText.continueWith,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_isSigningIn)
                                        const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
