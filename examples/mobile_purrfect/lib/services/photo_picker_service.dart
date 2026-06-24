import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a photo from the device gallery.
///
/// A contract (not a typedef) so tests inject a fake that returns fixed bytes.
// ignore: one_member_abstracts
abstract interface class PhotoPickerService {
  /// Returns the chosen image bytes, or null when the user cancels.
  Future<Uint8List?> pickImage();
}

/// The real picker, backed by `image_picker`.
class ImagePickerPhotoService implements PhotoPickerService {
  /// Creates the image-picker service.
  const ImagePickerPhotoService();

  @override
  Future<Uint8List?> pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
    );
    return file?.readAsBytes();
  }
}

/// The injected picker (overridden with a fake in tests).
final Provider<PhotoPickerService> photoPickerServiceProvider = Provider<PhotoPickerService>(
  (ref) => const ImagePickerPhotoService(),
);
