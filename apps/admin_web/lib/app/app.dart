import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'router.dart';

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  void initState() {
    super.initState();
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerDeviceToken());
    });
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    super.dispose();
  }

  Future<void> _registerDeviceToken() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    try {
      await ref.read(apiClientProvider).post(
            '/device-tokens',
            data: {
              'token': token,
              'platform': platform,
            },
          );
    } catch (_) {
      // Best-effort only.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, (_, next) {
      if (next.valueOrNull != null) {
        unawaited(_registerDeviceToken());
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: appTitleForMode(AppMode.admin),
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
