import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Handles camera / gallery capture and upload to the private
/// `proof-of-delivery` storage bucket.
class PodUploadService {
  PodUploadService(this._client);

  final SupabaseClient _client;
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  /// Pick from camera or gallery.
  Future<XFile?> pickImage({bool fromCamera = true}) async {
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
  }

  /// Upload bytes to `proof-of-delivery/photos/{shipmentId}/{uuid}.jpg`
  /// Returns the storage path (not a public URL).
  Future<String> uploadPhoto({
    required String shipmentId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final objectPath =
        'photos/$shipmentId/${_uuid.v4()}.jpg';

    await _client.storage.from('proof-of-delivery').uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );

    // Return the path the RPC expects (bucket-relative).
    return 'proof-of-delivery/$objectPath';
  }

  /// Convenience: pick + upload in one step.
  Future<String?> captureAndUpload(String shipmentId) async {
    final file = await pickImage(fromCamera: true);
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return uploadPhoto(shipmentId: shipmentId, bytes: bytes);
  }
}
