import 'dart:ui';

import 'package:flutter/material.dart';

enum AppBackdropVariant {
  customer,
  worker,
  admin,
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
    this.variant = AppBackdropVariant.customer,
  });

  final Widget child;
  final AppBackdropVariant variant;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final base = switch (variant) {
      AppBackdropVariant.customer => const Color(0xFFF9F5EC),
      AppBackdropVariant.worker => const Color(0xFFF5F7FB),
      AppBackdropVariant.admin => const Color(0xFFF3F4F6),
    };
    final end = switch (variant) {
      AppBackdropVariant.customer => const Color(0xFFFFFCF8),
      AppBackdropVariant.worker => const Color(0xFFFFFFFF),
      AppBackdropVariant.admin => const Color(0xFFFFFFFF),
    };
    final orbA = switch (variant) {
      AppBackdropVariant.customer => const Color(0xFFC2A15E),
      AppBackdropVariant.worker => const Color(0xFF0F766E),
      AppBackdropVariant.admin => const Color(0xFF2563EB),
    };
    final orbB = switch (variant) {
      AppBackdropVariant.customer => const Color(0xFFF59E0B),
      AppBackdropVariant.worker => const Color(0xFF38BDF8),
      AppBackdropVariant.admin => const Color(0xFF8B5CF6),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF16120D) : base,
            isDark ? const Color(0xFF1B1712) : end,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -90,
            child: _BackdropOrb(color: orbA.withValues(alpha: isDark ? 0.12 : 0.18), size: 260),
          ),
          Positioned(
            top: 70,
            right: -80,
            child: _BackdropOrb(color: orbB.withValues(alpha: isDark ? 0.12 : 0.14), size: 220),
          ),
          Positioned(
            bottom: -120,
            left: 60,
            child: _BackdropOrb(color: orbB.withValues(alpha: isDark ? 0.08 : 0.12), size: 240),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
