import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
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
  bool _isGoogleButtonAvailable = true;
  String? _initError;

  String _friendlyAuthError(Object? error) {
    var message = error?.toString() ?? '';
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        message = data['message']?.toString() ?? message;
      }
    }
    if (message.contains('Google sign-in is not configured')) {
      return 'Google sign-in is not configured on the server.';
    }
    if (message.contains('not configured for this app') ||
        message.contains('audience')) {
      return 'Google sign-in is using the wrong client ID.';
    }
    if (message.contains('Unauthorized') || message.contains('401')) {
      return 'This Google account could not be verified.';
    }
    if (message.contains('500') || message.contains('503')) {
      return 'Google sign-in is temporarily unavailable.';
    }
    if (message.isNotEmpty && message != 'null') {
      final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      return compact.length > 180 ? '${compact.substring(0, 177)}...' : compact;
    }
    return 'Unable to sign in right now.';
  }

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
          _isGoogleButtonAvailable = false;
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
      _isGoogleButtonAvailable = false;
      _initError = 'Google sign-in is not configured for this environment.';
      return;
    }

    unawaited(
      _googleSignIn.signInSilently().catchError((Object error) {
        if (!mounted) {
          return null;
        }
        setState(() {
          _isGoogleButtonAvailable = false;
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
            content: const Text(
                'This Google account is not authorized for admin access.'),
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

      final message = _friendlyAuthError(error);
      setState(() {
        _initError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
            content: Text(_friendlyAuthError(next.error)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 900;

    final form = Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _buildSignInCard(theme),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: SafeArea(
        child: compact
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const AdminLogo(
                                  height: 40,
                                  color: AbzioTheme.lightTextPrimary,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Admin',
                                  style: theme.textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            _buildSignInCard(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(flex: 5, child: _buildBrandPanel(theme)),
                  Expanded(flex: 4, child: form),
                ],
              ),
      ),
    );
  }

  Widget _buildBrandPanel(ThemeData theme) {
    return Container(
      color: AbzioTheme.lightMuted,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminLogo(height: 52, color: AbzioTheme.lightTextPrimary),
            const SizedBox(height: 32),
            Text('Admin Control Center', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Manage platform operations, workers, and services.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInCard(ThemeData theme) {
    return VeeduFixCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome back', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Sign in with your authorized admin account to continue.',
            style: theme.textTheme.bodyMedium,
          ),
          if (_initError != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(AbzioTheme.inputRadius),
              ),
              child: Text(
                _initError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: VeeduFixDesignSystem.buttonHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isSigningIn || !_isGoogleButtonAvailable,
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
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
