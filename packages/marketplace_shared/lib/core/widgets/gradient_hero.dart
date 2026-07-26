import 'package:flutter/material.dart';

class GradientHero extends StatelessWidget {
  const GradientHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.action,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0EA5A5), Color(0xFF22C55E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onPressed: action,
            child: Text(actionLabel),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
