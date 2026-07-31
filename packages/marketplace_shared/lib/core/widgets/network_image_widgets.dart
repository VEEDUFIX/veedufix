import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/image_utils.dart';
import '../../ui/widgets/shimmer_widget.dart';

class MarketplaceNetworkImage extends StatelessWidget {
  const MarketplaceNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 16,
    this.optimizeCloudinary = true,
    this.cloudinaryWidth = 200,
    this.cloudinaryHeight = 200,
    this.placeholderStrokeWidth = 2,
    this.errorIcon = Icons.broken_image_rounded,
    this.backgroundColor,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;
  final bool optimizeCloudinary;
  final int cloudinaryWidth;
  final int cloudinaryHeight;
  final double placeholderStrokeWidth;
  final IconData errorIcon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolveUrl();
    final fallback = Container(
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(errorIcon, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: resolvedUrl == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: fit,
                placeholder: (context, _) => SizedBox.expand(
                  child: ShimmerWidget(
                    radius: borderRadius,
                    child: Container(
                      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                errorWidget: (context, _, __) => fallback,
              ),
      ),
    );
  }

  String? _resolveUrl() {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    if (!optimizeCloudinary) {
      return raw;
    }

    return ImageUtils.getOptimizedCloudinaryUrl(
      raw,
      width: cloudinaryWidth,
      height: cloudinaryHeight,
    );
  }
}

class MarketplaceNetworkAvatar extends StatelessWidget {
  const MarketplaceNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallback,
    this.backgroundColor,
    this.optimizeCloudinary = true,
    this.cloudinarySize = 200,
  });

  final String? imageUrl;
  final double radius;
  final Widget fallback;
  final Color? backgroundColor;
  final bool optimizeCloudinary;
  final int cloudinarySize;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final resolvedUrl = _resolveUrl();
    final fallbackContainer = Container(
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: fallback,
    );

    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: resolvedUrl == null
            ? fallbackContainer
            : CachedNetworkImage(
                imageUrl: resolvedUrl,
                fit: BoxFit.cover,
                placeholder: (context, _) => SizedBox.expand(
                  child: ShimmerWidget(
                    radius: diameter,
                    child: Container(
                      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                errorWidget: (context, _, __) => fallbackContainer,
              ),
      ),
    );
  }

  String? _resolveUrl() {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    if (!optimizeCloudinary) {
      return raw;
    }

    return ImageUtils.getOptimizedCloudinaryUrl(
      raw,
      width: cloudinarySize,
      height: cloudinarySize,
    );
  }
}
