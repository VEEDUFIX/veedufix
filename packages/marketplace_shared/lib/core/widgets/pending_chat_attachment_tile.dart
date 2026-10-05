import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Preview of a chat image that has uploaded but has not been sent yet.
class PendingChatAttachmentTile extends StatelessWidget {
  const PendingChatAttachmentTile({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.onRemove,
  });

  final String imageUrl;
  final String? name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: name == null ? 'Photo attachment' : 'Photo attachment: $name',
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl.trim().isEmpty
                    ? _placeholder(colorScheme)
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            _placeholder(colorScheme),
                        errorWidget: (context, url, error) =>
                            _placeholder(colorScheme),
                      ),
              ),
            ),
            Positioned(
              top: 3,
              right: 3,
              child: Tooltip(
                message: 'Remove photo',
                child: Material(
                  color: Colors.black.withValues(alpha: 0.68),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
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

  Widget _placeholder(ColorScheme colorScheme) => ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
}
