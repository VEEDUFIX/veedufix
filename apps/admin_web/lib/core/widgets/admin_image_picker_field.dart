import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AdminImagePickerField extends StatefulWidget {
  const AdminImagePickerField({
    required this.value,
    required this.onChanged,
    required this.uploadImage,
    this.label = 'Image',
    this.recommendedWidth = 1200,
    this.recommendedHeight = 900,
    this.showCustomerPreview = false,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final Future<String> Function(Uint8List bytes, String fileName) uploadImage;
  final String label;
  final int recommendedWidth;
  final int recommendedHeight;
  final bool showCustomerPreview;

  double get recommendedAspectRatio => recommendedWidth / recommendedHeight;

  @override
  State<AdminImagePickerField> createState() => _AdminImagePickerFieldState();
}

class _AdminImagePickerFieldState extends State<AdminImagePickerField> {
  static const _maximumBytes = 10 * 1024 * 1024;
  Uint8List? _pendingBytes;
  String? _pendingFileName;
  int? _pendingWidth;
  int? _pendingHeight;
  bool _uploading = false;
  String? _error;

  Future<void> _chooseImage() async {
    FilePickerResult? selection;
    try {
      selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: true,
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the image picker.');
      return;
    }
    if (selection == null || selection.files.isEmpty) return;
    if (!mounted) return;

    final file = selection.files.single;
    final bytes = file.bytes;
    final extension = file.extension?.toLowerCase();
    if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
      setState(() => _error = 'Choose a JPG or PNG image.');
      return;
    }
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Could not read the selected image.');
      return;
    }
    if (bytes.length > _maximumBytes) {
      setState(() => _error = 'Choose an image no larger than 10 MB.');
      return;
    }

    late final int width;
    late final int height;
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The selected file is not a valid image.');
      }
      return;
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
    if (!mounted) return;
    setState(() {
      _pendingBytes = bytes;
      _pendingFileName = file.name;
      _pendingWidth = width;
      _pendingHeight = height;
      _error = null;
    });
  }

  Future<void> _uploadPendingImage() async {
    final bytes = _pendingBytes;
    final fileName = _pendingFileName;
    if (bytes == null || fileName == null || _uploading) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.uploadImage(bytes, fileName);
      if (!mounted) return;
      widget.onChanged(url);
      setState(() {
        _pendingBytes = null;
        _pendingFileName = null;
        _pendingWidth = null;
        _pendingHeight = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Image upload failed. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _previewImage({
    Uint8List? bytes,
    String? url,
    required String title,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton(
                        tooltip: 'Close preview',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.showCustomerPreview) ...[
                    Text('Original preview',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: _previewDecoration(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _image(
                          bytes: bytes,
                          url: url,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Customer preview',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Center(
                        child: _customerCrop(context, bytes: bytes, url: url)),
                  ] else
                    InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 640,
                            maxHeight: 620,
                          ),
                          child: _image(
                            bytes: bytes,
                            url: url,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _removeImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove image?'),
        content: const Text(
          'This image will be removed from this item when you save your changes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep image'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _pendingBytes = null;
      _pendingFileName = null;
      _pendingWidth = null;
      _pendingHeight = null;
      _error = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.value?.trim();
    final hasCurrentImage = imageUrl != null && imageUrl.isNotEmpty;
    final hasPendingImage = _pendingBytes != null;
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (!hasCurrentImage && !hasPendingImage)
          _emptyState(context)
        else if (widget.showCustomerPreview)
          _bannerPreviews(
            context,
            bytes: hasPendingImage ? _pendingBytes : null,
            url: hasPendingImage ? null : imageUrl,
          )
        else
          _standardPreview(
            context,
            bytes: hasPendingImage ? _pendingBytes : null,
            url: hasPendingImage ? null : imageUrl,
          ),
        if (hasCurrentImage && hasPendingImage) ...[
          const SizedBox(height: 8),
          Text('Current image', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          _standardPreview(context, url: imageUrl, compact: true),
        ],
        if (hasPendingImage) ...[
          const SizedBox(height: 10),
          _fileDetails(context),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (hasCurrentImage || hasPendingImage)
              OutlinedButton.icon(
                onPressed: _uploading
                    ? null
                    : () => _previewImage(
                          bytes: hasPendingImage ? _pendingBytes : null,
                          url: hasPendingImage ? null : imageUrl,
                          title: widget.label,
                        ),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Preview'),
              ),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _chooseImage,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(hasCurrentImage || hasPendingImage
                  ? 'Replace'
                  : 'Choose image'),
            ),
            if (hasCurrentImage || hasPendingImage)
              TextButton.icon(
                onPressed: _uploading ? null : _removeImage,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            if (hasPendingImage)
              FilledButton.icon(
                onPressed: _uploading ? null : _uploadPendingImage,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? 'Uploading…' : 'Upload image'),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 112),
      decoration: _previewDecoration(context),
      child: InkWell(
        onTap: _uploading ? null : _chooseImage,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: colors.onSurfaceVariant),
              const SizedBox(height: 6),
              const Text('Choose an image to preview it here'),
              const SizedBox(height: 3),
              Text(
                'JPG or PNG · up to 10 MB',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standardPreview(
    BuildContext context, {
    Uint8List? bytes,
    String? url,
    bool compact = false,
  }) {
    final ratio = widget.recommendedAspectRatio;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: compact ? 90 : 220),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Container(
          decoration: _previewDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _image(
              bytes: bytes,
              url: url,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerPreviews(
    BuildContext context, {
    Uint8List? bytes,
    String? url,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Original preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 190),
          decoration: _previewDecoration(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _image(
              bytes: bytes,
              url: url,
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('Customer preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 328),
            child: _customerCrop(context, bytes: bytes, url: url),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '328 × 172 dp · BoxFit.cover',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _customerCrop(
    BuildContext context, {
    Uint8List? bytes,
    String? url,
  }) {
    return AspectRatio(
      aspectRatio: 328 / 172,
      child: Container(
        decoration: _previewDecoration(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _image(
            bytes: bytes,
            url: url,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }

  Widget _fileDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = _pendingWidth ?? 0;
    final height = _pendingHeight ?? 0;
    final ratio = height == 0 ? 0.0 : width / height;
    final fileSize = _formatBytes(_pendingBytes?.length ?? 0);
    final ratioDelta = widget.recommendedAspectRatio == 0
        ? 0.0
        : ((ratio - widget.recommendedAspectRatio).abs() /
            widget.recommendedAspectRatio);
    final hasCropWarning = ratioDelta > 0.15;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_pendingFileName ?? 'Selected image',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(
            '$width × $height px · ${ratio.toStringAsFixed(2)}:1 · $fileSize · ${_extensionLabel(_pendingFileName)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Text(
            'Recommended: ${widget.recommendedWidth} × ${widget.recommendedHeight} px · ${widget.recommendedAspectRatio.toStringAsFixed(2)}:1 · JPG or PNG · max 10 MB',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (hasCropWarning) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: colors.tertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This aspect ratio differs from the recommendation. Review the preview for possible cropping; the image will not be stretched.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _image({
    Uint8List? bytes,
    String? url,
    required BoxFit fit,
    required Alignment alignment,
  }) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    if (url == null || url.isEmpty) return placeholder;
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }

  BoxDecoration _previewDecoration(BuildContext context) => BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      );

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _extensionLabel(String? fileName) {
    final extension = fileName?.split('.').last.toUpperCase();
    return extension == null || extension.isEmpty ? 'Image' : extension;
  }
}
