import 'package:app_settings/app_settings.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/core/photos/lost_capture.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Long enough to read the access hint and reach the settings button.
const _actionSnackBarDuration = Duration(seconds: 8);

/// What to tell the user when image_picker fails. A refused permission
/// (Android only reports the camera one) can be fixed in the app settings.
({String message, bool offerSettings}) describePhotoPickError(
  AppLocalizations l10n,
  Object error,
) => switch (error) {
  PlatformException(code: 'camera_access_denied') => (
    message: l10n.cameraAccessDenied,
    offerSettings: true,
  ),
  PlatformException(code: 'photo_access_denied') => (
    message: l10n.photoAccessDenied,
    offerSettings: true,
  ),
  _ => (message: l10n.photoPickError, offerSettings: false),
};

/// Takes a photo or picks up to [limit] from the gallery, for reports and
/// chat alike. Returns the originals' paths: no resizing here, the
/// `PhotoCompressor` does it properly. On failure a snack bar says why,
/// with «Настройки» when the camera permission was refused.
///
/// While the camera is open [target] is kept in local storage: if Android
/// kills the app meanwhile, `LostCaptureNotifier.recover()` brings the shot
/// back to it on the next start.
Future<List<String>> pickPhotos(
  BuildContext context,
  WidgetRef ref, {
  required ImageSource source,
  required int limit,
  required CaptureTarget target,
}) async {
  if (limit <= 0) return const [];
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picker = ref.read(photoPickerProvider);
  final storage = ref.read(localStorageProvider);
  try {
    final List<String> paths;
    if (source == ImageSource.camera) {
      // Best effort: without it a lost shot is only lost, as before.
      try {
        await storage.saveJson(pendingCaptureKey, target.toJson());
      } on Exception catch (e) {
        debugPrint('Pending capture not saved: $e');
      }
      try {
        paths = [?await picker.takePhoto()];
      } finally {
        try {
          await storage.remove(pendingCaptureKey);
        } on Exception catch (e) {
          debugPrint('Pending capture not removed: $e');
        }
      }
    } else {
      paths = await picker.pickFromGallery(limit: limit);
    }
    // Older Androids ignore the limit of the system picker.
    if (paths.length > limit) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.photoLimitReached(limit))),
      );
    }
    return paths.take(limit).toList();
  } on Exception catch (e) {
    // The exception text is for debugging, not for the user.
    debugPrint('Photo pick failed: $e');
    final error = describePhotoPickError(l10n, e);
    messenger.showSnackBar(
      error.offerSettings
          ? SnackBar(
              content: Text(error.message),
              duration: _actionSnackBarDuration,
              action: SnackBarAction(
                label: l10n.openSettings,
                onPressed: AppSettings.openAppSettings,
              ),
            )
          : SnackBar(content: Text(error.message)),
    );
    return const [];
  }
}
