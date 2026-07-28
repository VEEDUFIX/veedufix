import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:marketplace_shared/marketplace_shared.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final GoogleSignIn _googleSignIn;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final environment = ref.read(environmentProvider);
    _googleSignIn = GoogleSignIn(
      scopes: const ['openid', 'email', 'profile'],
      clientId: environment.googleServerClientId.isEmpty ? null : environment.googleServerClientId,
      serverClientId: environment.googleServerClientId.isEmpty ? null : environment.googleServerClientId,
    );

    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      if (account != null) {
        setState(() => _isLoading = true);
        try {
          final auth = await account.authentication;
          final idToken = auth.idToken;
          if (idToken == null || idToken.isEmpty) {
            throw StateError('Google did not return an identity token.');
          }
          await ref.read(authControllerProvider.notifier).signInWithGoogle(
                idToken: idToken,
                role: 'ADMIN',
              );
          
          final authState = ref.read(authControllerProvider);
          if (authState.hasError) {
            throw authState.error ?? StateError('Backend authentication failed');
          }

          if (!mounted) return;
          context.go('/admin');
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google sign-in failed: $error')),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    });
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
            role: 'ADMIN',
          );
      if (!mounted) return;
      context.go('/admin');
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF06131F), Color(0xFF0F766E), Color(0xFF14B8A6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'VeeduFix Admin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Google sign-in for city operations, support, pricing, and platform control.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    elevation: 0,
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Authorized admin access only',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Continue with your approved Google account to access the dashboard.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.84),
                                ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            alignment: Alignment.center,
                            height: 44,
                            child: (GoogleSignInPlatform.instance as web.GoogleSignInPlugin).renderButton(
                              configuration: web.GSIButtonConfiguration(
                                size: web.GSIButtonSize.large,
                                text: web.GSIButtonText.continueWith,
                              ),
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
        ),
      ),
    );
  }
}
