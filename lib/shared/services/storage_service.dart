import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import 'supabase_service.dart';

class StorageService {
  static const productImages = 'product-images';
  static const cms = 'cms';
  static const pod = 'pod';

  static String resolvePublicUrl(String? path, {String bucket = productImages}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (!Env.isConfigured) return path;
    return SupabaseService.client.storage.from(bucket).getPublicUrl(path);
  }

  static Future<String> signedUrl(String path, {String bucket = pod, int expires = 300}) async {
    if (path.startsWith('http')) return path;
    final res = await SupabaseService.client.storage.from(bucket).createSignedUrl(path, expires);
    return res;
  }

  static Future<String> upload({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!Env.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    await SupabaseService.client.storage.from(bucket).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return objectPath;
  }
}
