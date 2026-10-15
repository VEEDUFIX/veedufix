import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/booking_diagnostic_photos_provider.dart';

class BookingDiagnosticPhotosSection extends ConsumerWidget {
  const BookingDiagnosticPhotosSection(
      {super.key,
      required this.bookingId,
      this.showEmpty = false,
      this.photoIds});
  final String bookingId;
  final bool showEmpty;
  final List<String>? photoIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingDiagnosticPhotosProvider(bookingId));
    return state.when(
      loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Issue photos unavailable',
        message: 'Check your connection and try again.',
        action: TextButton.icon(
            onPressed: () =>
                ref.invalidate(bookingDiagnosticPhotosProvider(bookingId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ),
      data: (photos) {
        final visiblePhotos = photoIds == null
            ? photos
            : photos.where((photo) => photoIds!.contains(photo.id)).toList();
        if (visiblePhotos.isEmpty && !showEmpty) return const SizedBox.shrink();
        if (visiblePhotos.isEmpty)
          return const _MessageCard(
              icon: Icons.image_not_supported_outlined,
              title: 'No issue photos',
              message: 'No diagnostic photos were attached to this booking.');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Issue photos',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final photo in visiblePhotos) _PhotoThumbnail(photo: photo)
          ]),
        ]);
      },
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.photo});
  final BookingDiagnosticPhoto photo;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: 'Open issue photo',
      child: InkWell(
        excludeFromSemantics: true,
        borderRadius: BorderRadius.circular(14),
        onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
                  insetPadding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                        child: Image.network(photo.url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox(
                                height: 180,
                                child: Center(
                                    child:
                                        Text('Photo could not be loaded'))))),
                  ),
                )),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(14)),
            child: Image.network(photo.url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, loadingProgress) =>
                    loadingProgress == null
                        ? child
                        : const Center(
                            child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))),
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined))),
          ),
        ),
      ));
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(
      {required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
                if (action != null)
                  Align(alignment: Alignment.centerLeft, child: action!),
              ])),
        ]),
      );
}
