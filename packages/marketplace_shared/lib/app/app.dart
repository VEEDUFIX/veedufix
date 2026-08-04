import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router.dart';
import 'theme.dart';

class AppBootstrap extends ConsumerWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Marketplace App',
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        final textTheme = GoogleFonts.plusJakartaSansTextTheme(Theme.of(context).textTheme);
        return Theme(
          data: Theme.of(context).copyWith(textTheme: textTheme),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
