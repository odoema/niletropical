import 'dart:typed_data';
import 'dart:ui' as ui;

class ImageQualityResult {
  const ImageQualityResult({
    required this.width,
    required this.height,
    required this.bytes,
    required this.minWidth,
    required this.minHeight,
  });

  final int width;
  final int height;
  final int bytes;
  final int minWidth;
  final int minHeight;

  bool get passes => width >= minWidth && height >= minHeight;
  String get dimensions => '${width} × ${height}';

  String get sizeLabel {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

class ImageQualityService {
  static const profiles = <String, ({int minWidth, int minHeight, String label})>{
    'website': (minWidth: 1200, minHeight: 800, label: 'Website image'),
    'banners': (minWidth: 1600, minHeight: 600, label: 'Banner'),
    'testimonials': (minWidth: 600, minHeight: 600, label: 'Testimonial photo'),
    'videos': (minWidth: 1280, minHeight: 720, label: 'Video thumbnail'),
  };

  static Future<ImageQualityResult> inspect({
    required Uint8List bytes,
    required String folder,
  }) async {
    final profile = profiles[folder] ?? profiles['website']!;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final result = ImageQualityResult(
      width: frame.image.width,
      height: frame.image.height,
      bytes: bytes.length,
      minWidth: profile.minWidth,
      minHeight: profile.minHeight,
    );
    frame.image.dispose();
    codec.dispose();
    return result;
  }

  static String guidance(String folder) {
    final profile = profiles[folder] ?? profiles['website']!;
    return '${profile.label}: minimum ${profile.minWidth} × ${profile.minHeight}px. '
        'Original files are uploaded without forced compression.';
  }
}
