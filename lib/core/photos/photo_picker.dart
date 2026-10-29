import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Photos lost while Android had killed the app: the paths it hands over
/// on the next start, or the error the picker hit.
typedef LostPhotos = ({List<String> paths, Object? error});

/// The system camera and gallery. Throws what image_picker throws
/// (`PlatformException('camera_access_denied')`, …): `pickPhotos` turns it
/// into a snack bar. Tests override `photoPickerProvider`.
abstract class PhotoPicker {
  /// A shot from the camera, or `null` if the user backed out.
  Future<String?> takePhoto();

  /// Up to [limit] photos from the gallery.
  Future<List<String>> pickFromGallery({required int limit});

  /// What the picker returned while the app was dead. Android may kill the
  /// app while the camera is in front; the shot then comes back here on
  /// the next start, once.
  Future<LostPhotos> retrieveLost();
}

/// [PhotoPicker] over image_picker. Originals only: no resizing here, the
/// `PhotoCompressor` does it properly.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> takePhoto() async =>
      (await _picker.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<List<String>> pickFromGallery({required int limit}) async {
    // pickMultiImage wants a limit of at least 2.
    if (limit == 1) {
      final one = await _picker.pickImage(source: ImageSource.gallery);
      return [?one?.path];
    }
    final files = await _picker.pickMultiImage(limit: limit);
    return [for (final f in files) f.path];
  }

  @override
  Future<LostPhotos> retrieveLost() async {
    // Only Android kills the app under the camera this way.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return (paths: const <String>[], error: null);
    }
    final response = await _picker.retrieveLostData();
    return (
      paths: [for (final f in response.files ?? const <XFile>[]) f.path],
      error: response.exception,
    );
  }
}
