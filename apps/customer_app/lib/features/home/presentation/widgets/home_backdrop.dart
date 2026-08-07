import 'package:flutter/material.dart';

class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.07),
              cs.surface,
              cs.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -48,
              child: AmbientOrb(color: cs.primary.withValues(alpha: 0.12), size: 180),
            ),
            Positioned(
              top: 180,
              left: -64,
              child: AmbientOrb(color: const Color(0xFF10B981).withValues(alpha: 0.10), size: 140),
            ),
          ],
        ),
      ),
    );
  }
}

class AmbientOrb extends StatelessWidget {
  const AmbientOrb({
    super.key,
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
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
