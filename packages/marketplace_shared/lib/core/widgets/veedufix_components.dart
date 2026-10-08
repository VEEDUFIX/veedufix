import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/veedufix_design_system.dart';
import 'network_image_widgets.dart';

/// Brand primary action. Use for the single most important action in a region.
class VeeduFixButton extends StatelessWidget {
  const VeeduFixButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: VeeduFixDesignSystem.buttonHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VeeduFixDesignSystem.ink,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: VeeduFixDesignSystem.space8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Quiet bordered action for a secondary choice.
class VeeduFixSecondaryButton extends StatelessWidget {
  const VeeduFixSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: VeeduFixDesignSystem.space8),
              Text(label),
            ],
          );
    final child = SizedBox(
      height: VeeduFixDesignSystem.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        child: content,
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

/// Shared mobile number input used by Customer and Partner authentication.
class VeeduFixPhoneField extends StatelessWidget {
  const VeeduFixPhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.trailing,
    this.hasError = false,
    this.dialCode = '+91',
    this.hintText = '98765 43210',
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? trailing;
  final bool hasError;
  final String dialCode;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderColor = hasError
        ? colors.error
        : focusNode.hasFocus
            ? VeeduFixDesignSystem.gold
            : VeeduFixDesignSystem.border;
    return Container(
      height: VeeduFixDesignSystem.inputHeight,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusMedium),
        border:
            Border.all(color: borderColor, width: focusNode.hasFocus ? 1.5 : 1),
      ),
      child: Row(
        children: [
          const SizedBox(width: VeeduFixDesignSystem.space16),
          Text(dialCode, style: Theme.of(context).textTheme.bodyLarge),
          Container(
            width: 1,
            height: 22,
            margin: const EdgeInsets.symmetric(
                horizontal: VeeduFixDesignSystem.space12),
            color: VeeduFixDesignSystem.border,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: VeeduFixDesignSystem.space12),
          ] else
            const SizedBox(width: VeeduFixDesignSystem.space16),
        ],
      ),
    );
  }
}

/// Surface for a meaningful grouped content block, without default Card
/// elevation or oversized rounding.
class VeeduFixCard extends StatelessWidget {
  const VeeduFixCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(VeeduFixDesignSystem.space16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: VeeduFixDesignSystem.border),
            borderRadius:
                BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
          ),
          child: content,
        ),
      ),
    );
  }
}

class VeeduFixSectionHeader extends StatelessWidget {
  const VeeduFixSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: VeeduFixDesignSystem.space4),
                Text(subtitle!, style: text.bodySmall),
              ],
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Calm content card for a featured action or promotion.
class VeeduFixFeatureCard extends StatelessWidget {
  const VeeduFixFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return VeeduFixCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: VeeduFixDesignSystem.gold.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(VeeduFixDesignSystem.radiusMedium),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: VeeduFixDesignSystem.gold, size: 21),
          ),
          const SizedBox(width: VeeduFixDesignSystem.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: VeeduFixDesignSystem.space4),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Catalog service tile with a consistent title, price, rating, and image
/// treatment. Use [compact] in dense category/search grids.
class VeeduFixServiceCard extends StatelessWidget {
  const VeeduFixServiceCard({
    super.key,
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.category,
    this.subtitle,
    this.rating,
    this.priceLabel,
    this.placeholderIcon = Icons.home_repair_service_rounded,
    this.compact = false,
    this.imageHeight = 116,
  });

  final String title;
  final VoidCallback onTap;
  final String? imageUrl;
  final String? category;
  final String? subtitle;
  final String? rating;
  final String? priceLabel;
  final IconData placeholderIcon;
  final bool compact;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final image = compact
        ? Container(
            height: 72,
            width: double.infinity,
            color: VeeduFixDesignSystem.ivory,
            alignment: Alignment.center,
            child: Icon(
              placeholderIcon,
              size: 28,
              color: VeeduFixDesignSystem.gold,
            ),
          )
        : imageUrl?.trim().isNotEmpty == true
            ? MarketplaceNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: imageHeight,
                borderRadius: 0,
                cloudinaryWidth: 400,
                cloudinaryHeight: 300,
                errorIcon: placeholderIcon,
                backgroundColor: VeeduFixDesignSystem.ivory,
              )
            : Container(
                height: imageHeight,
                width: double.infinity,
                color: VeeduFixDesignSystem.ivory,
                alignment: Alignment.center,
                child: Icon(
                  placeholderIcon,
                  size: 36,
                  color: VeeduFixDesignSystem.gold,
                ),
              );

    return Semantics(
      button: true,
      label: [title, if (priceLabel != null) priceLabel!].join(', '),
      child: VeeduFixCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VeeduFixDesignSystem.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              image,
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(VeeduFixDesignSystem.space12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact && category?.trim().isNotEmpty == true) ...[
                        Text(
                          category!.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall,
                        ),
                        const SizedBox(height: VeeduFixDesignSystem.space4),
                      ],
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      if (compact && subtitle?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: VeeduFixDesignSystem.space4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      ],
                      if (!compact && rating != null) ...[
                        const SizedBox(height: VeeduFixDesignSystem.space8),
                        _ServiceRating(label: rating!),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          if (priceLabel != null)
                            Expanded(
                              child: Text(
                                priceLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall,
                              ),
                            ),
                          if (compact && rating != null) ...[
                            if (priceLabel != null)
                              const SizedBox(
                                  width: VeeduFixDesignSystem.space8),
                            _ServiceRating(label: rating!),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRating extends StatelessWidget {
  const _ServiceRating({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          size: 14,
          color: VeeduFixDesignSystem.gold,
        ),
        const SizedBox(width: VeeduFixDesignSystem.space4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class VeeduFixNavDestination {
  const VeeduFixNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Shared, safe-area aware bottom navigation for the mobile marketplace apps.
class VeeduFixBottomNav extends StatelessWidget {
  const VeeduFixBottomNav({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final List<VeeduFixNavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: index == selectedIndex,
                  label: destinations[index].label,
                  child: InkResponse(
                    onTap: () => onDestinationSelected(index),
                    radius: 32,
                    child: SizedBox.expand(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            index == selectedIndex
                                ? destinations[index].selectedIcon
                                : destinations[index].icon,
                            size: 23,
                            color: index == selectedIndex
                                ? VeeduFixDesignSystem.gold
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            destinations[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: index == selectedIndex
                                  ? colors.onSurface
                                  : colors.onSurfaceVariant,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
