import 'package:flutter/material.dart';
import '../theme/veedufix_design_system.dart';
import 'veedufix_components.dart';

class PremiumSectionHeader extends VeeduFixSectionHeader {
  const PremiumSectionHeader({
    super.key,
    required super.title,
    super.subtitle,
    super.actionLabel,
    super.onAction,
  });
}

class PremiumStatCard extends StatelessWidget {
  const PremiumStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VeeduFixDesignSystem.space16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusSmall),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(width: VeeduFixDesignSystem.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.72),
                      ),
                ),
                const SizedBox(height: VeeduFixDesignSystem.space4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumCard extends StatelessWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return VeeduFixCard(onTap: onTap, child: child);
  }
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VeeduFixDesignSystem.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
              ),
              child: Icon(
                icon,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: VeeduFixDesignSystem.space16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: VeeduFixDesignSystem.space8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.72),
                  ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: VeeduFixDesignSystem.space16),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: VeeduFixButton(
                    icon: Icons.refresh_rounded,
                    onPressed: onAction,
                    label: actionLabel!,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PremiumRetryState extends StatelessWidget {
  const PremiumRetryState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.actionLabel = 'Try again',
    this.onRefresh,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;
  final IconData icon;
  final String actionLabel;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: () async {
          if (onRefresh == null) {
            onRetry();
            return;
          }
          try {
            await onRefresh!();
          } catch (_) {}
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(VeeduFixDesignSystem.space24),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: PremiumEmptyState(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  actionLabel: actionLabel,
                  onAction: onRetry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(
          borderRadius ?? VeeduFixDesignSystem.radiusLarge,
        ),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: child,
    );
  }
}
