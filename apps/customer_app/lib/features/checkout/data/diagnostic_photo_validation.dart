import 'dart:typed_data';

const int diagnosticPhotoMaxBytes = 10 * 1024 * 1024;

/// Returns null for JPEG/PNG bytes within the upload limit, otherwise a UI-safe error.
String? validateDiagnosticPhotoBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return 'Choose a photo with image data.';
  }
  if (bytes.length > diagnosticPhotoMaxBytes) {
    return 'Each photo must be under 10 MB.';
  }
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  const pngSignature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  final png =
      bytes.length >= pngSignature.length &&
      List<bool>.generate(
        pngSignature.length,
        (index) => bytes[index] == pngSignature[index],
      ).every((matches) => matches);
  if (!jpeg && !png) {
    return 'Choose a valid JPEG or PNG image.';
  }
  return null;
}
