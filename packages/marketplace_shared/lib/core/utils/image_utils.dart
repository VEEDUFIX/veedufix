class ImageUtils {
  /// Appends Cloudinary transformation parameters to scale down the image before download.
  /// Example: https://res.cloudinary.com/demo/image/upload/sample.jpg 
  /// becomes: https://res.cloudinary.com/demo/image/upload/w_200,h_200,c_fill/sample.jpg
  static String getOptimizedCloudinaryUrl(String? url, {int width = 200, int height = 200}) {
    if (url == null || url.isEmpty) return '';
    if (!url.contains('cloudinary.com')) return url;
    if (url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/w_$width,h_$height,c_fill/');
    }
    return url;
  }
}
