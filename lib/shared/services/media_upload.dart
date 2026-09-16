import 'package:image_picker/image_picker.dart';
import 'storage_service.dart';

class MediaUpload {
  static Future<String?> pickAndUpload({
    required String bucket,
    required String objectPath,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final ct = file.mimeType ?? 'image/jpeg';
    return StorageService.upload(
      bucket: bucket,
      objectPath: objectPath,
      bytes: bytes,
      contentType: ct,
    );
  }
}
