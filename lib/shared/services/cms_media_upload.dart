import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_quality_service.dart';
import 'storage_service.dart';

class CmsMediaUploadResult {
  const CmsMediaUploadResult({
    required this.path,
    required this.quality,
  });

  final String path;
  final ImageQualityResult quality;
}

class CmsMediaUpload {
  static Future<CmsMediaUploadResult?> pickAndUpload({
    required BuildContext context,
    required String folder,
    required String objectPrefix,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final quality = await ImageQualityService.inspect(
      bytes: bytes,
      folder: folder,
    );

    if (!quality.passes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Image rejected: ${quality.dimensions}. '
              'Minimum is ${quality.minWidth} × ${quality.minHeight}px.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final safe = file.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final path =
        '$folder/$objectPrefix-${DateTime.now().millisecondsSinceEpoch}-$safe';

    final uploaded = await StorageService.upload(
      bucket: StorageService.cms,
      objectPath: path,
      bytes: bytes,
      contentType: file.mimeType ?? 'image/jpeg',
    );

    return CmsMediaUploadResult(path: uploaded, quality: quality);
  }
}
