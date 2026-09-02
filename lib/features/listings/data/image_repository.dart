import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// ImageRepository: picks listing photos and uploads them to Cloud Storage.
///
/// Compression happens at pick time via [ImagePicker]'s own resize and quality
/// options rather than a separate compression package — it keeps a phone photo
/// under the 5 MB ceiling `storage.rules` enforces without another native
/// dependency.
class ImageRepository {
  ImageRepository({ImagePicker? picker, FirebaseStorage? storage})
    : _picker = picker ?? ImagePicker(),
      _storage = storage ?? FirebaseStorage.instance;

  final ImagePicker _picker;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// How many photos one listing may carry.
  static const int maxImages = 5;

  /// Long edge, in pixels. A 4000px phone photo becomes ~1600px, which is
  /// plenty for a full-screen gallery and roughly a tenth of the bytes.
  static const double _maxDimension = 1600;

  /// JPEG quality after the resize.
  static const int _quality = 80;

  /// Opens the system photo picker. Returns at most [remainingSlots] files.
  Future<List<XFile>> pickFromGallery({int remainingSlots = maxImages}) async {
    if (remainingSlots <= 0) return const [];

    final picked = await _picker.pickMultiImage(
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
      limit: remainingSlots,
    );

    return picked.take(remainingSlots).toList();
  }

  /// Opens the camera. Returns null if the user backs out.
  Future<XFile?> pickFromCamera() {
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );
  }

  /// Uploads [files] for a listing and returns their download URLs, in order.
  ///
  /// [listingId] is generated before the Firestore document is written, so the
  /// images land under a path the listing will actually own.
  /// [onProgress] reports 0.0–1.0 across the whole batch.
  Future<List<String>> uploadListingImages({
    required String listingId,
    required List<XFile> files,
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return const [];

    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('You must be signed in to upload photos');

    final urls = <String>[];

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final ref = _storage.ref('listings/$uid/$listingId/$index.jpg');

      final task = ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          final total = snapshot.totalBytes;
          if (total <= 0) return;
          // Completed files plus how far the current one has got.
          final fileProgress = snapshot.bytesTransferred / total;
          onProgress((index + fileProgress) / files.length);
        }, onError: (Object _) {});
      }

      await task;
      urls.add(await ref.getDownloadURL());
    }

    onProgress?.call(1);
    return urls;
  }
}
