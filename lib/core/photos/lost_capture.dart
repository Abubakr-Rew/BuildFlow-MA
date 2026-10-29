import 'package:flutter/foundation.dart';

/// Local storage key of the [CaptureTarget] saved while the camera is open.
const pendingCaptureKey = 'pending_camera_capture';

enum CaptureKind { chat, report }

/// Where a camera shot belongs. Saved before the camera opens and removed
/// when it closes: if Android kills the app meanwhile, the next start knows
/// where to bring the shot back.
@immutable
class CaptureTarget {
  const CaptureTarget.chat({required this.userId, required String chatId})
      : kind = CaptureKind.chat,
        id = chatId;

  const CaptureTarget.report({required this.userId, String? projectId})
      : kind = CaptureKind.report,
        id = projectId;

  const CaptureTarget._(this.kind, this.userId, this.id);

  final CaptureKind kind;

  /// Who was taking the photo: someone else signed in gets nothing.
  final String userId;

  /// The chat, or the project of the report if one was chosen.
  final String? id;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'userId': userId,
        'id': id,
      };

  /// `null` for anything unreadable, e.g. written by another app version.
  static CaptureTarget? fromJson(Map<String, Object?> json) {
    final kind = CaptureKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final userId = json['userId'];
    final id = json['id'];
    if (kind == null || userId is! String || (id != null && id is! String)) {
      return null;
    }
    if (kind == CaptureKind.chat && id == null) return null;
    return CaptureTarget._(kind, userId, id as String?);
  }

  @override
  bool operator ==(Object other) =>
      other is CaptureTarget &&
      other.kind == kind &&
      other.userId == userId &&
      other.id == id;

  @override
  int get hashCode => Object.hash(kind, userId, id);

  @override
  String toString() => 'CaptureTarget(${kind.name}, $userId, $id)';
}

/// A shot recovered after the app was killed, waiting for its screen.
@immutable
class LostCapture {
  const LostCapture({required this.target, required this.paths});

  final CaptureTarget target;
  final List<String> paths;
}
