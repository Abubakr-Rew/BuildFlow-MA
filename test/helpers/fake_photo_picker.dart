import 'package:buildflow/core/photos/photo_picker.dart';

/// [PhotoPicker] for tests: returns what the test sets and records calls.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.shot, this.gallery = const [], this.lost = const []});

  /// What the camera returns; `null` as if the user backed out.
  String? shot;
  List<String> gallery;

  /// What comes back after the app was killed under the camera.
  List<String> lost;

  /// Thrown by the camera instead of returning, e.g. a refused permission.
  Exception? cameraError;

  /// Runs while the «camera» is open, e.g. to look at what was saved.
  Future<void> Function()? whileCameraOpen;

  int cameraOpened = 0;
  final List<int> galleryLimits = [];
  int lostRetrieved = 0;

  @override
  Future<String?> takePhoto() async {
    cameraOpened++;
    await whileCameraOpen?.call();
    if (cameraError case final error?) throw error;
    return shot;
  }

  @override
  Future<List<String>> pickFromGallery({required int limit}) async {
    galleryLimits.add(limit);
    return gallery;
  }

  @override
  Future<LostPhotos> retrieveLost() async {
    lostRetrieved++;
    final paths = lost;
    // Android hands a lost shot over once.
    lost = const [];
    return (paths: paths, error: null);
  }
}
