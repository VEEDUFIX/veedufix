import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:marketplace_shared/marketplace_shared.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'VeeduFix',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF0F766E),
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Admin Control Center',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                ),
                const SizedBox(height: 48),
                Card(
                  elevation: 2,
                  color: Colors.white,
                  shadowColor: Colors.black.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign In',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Authorized dashboard access only.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              ),
                        ),
                        const SizedBox(height: 32),
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
    );
  }
}
