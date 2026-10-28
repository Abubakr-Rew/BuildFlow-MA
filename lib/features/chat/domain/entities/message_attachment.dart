import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_attachment.freezed.dart';
part 'message_attachment.g.dart';

/// A file attached to a message: a photo (stage 2) or a voice note
/// (stage 3).
@freezed
abstract class MessageAttachment with _$MessageAttachment {
  const factory MessageAttachment({
    required String id,
    required String url,

    /// Photo size in pixels, for laying out before the image loads.
    int? width,
    int? height,

    /// Voice note length.
    int? durationMs,
  }) = _MessageAttachment;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      _$MessageAttachmentFromJson(json);
}
