import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5EDD8), // warm amber top
              AbzioTheme.lightBackground,
              AbzioTheme.lightBackground,
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _AmbientOrb(
                color: AbzioTheme.accentColor.withValues(alpha: 0.09),
                size: 200,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.color, required this.size});

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
            color: color.withValues(alpha: 0.3),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}
