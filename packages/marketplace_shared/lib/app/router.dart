import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_mode.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/otp_page.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/splash/presentation/pages/splash_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final session = authState.valueOrNull;

      if (authState.isLoading) {
        return location == '/splash' ? null : '/splash';
      }

      final isAuthRoute = location == '/login' || location == '/otp';

      if (session == null) {
        return isAuthRoute ? null : '/login';
      }

      if (location == '/splash') {
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(mode: AppMode.customer),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
    ],
  );
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}
