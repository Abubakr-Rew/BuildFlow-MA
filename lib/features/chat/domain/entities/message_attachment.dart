import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_attachment.freezed.dart';
part 'message_attachment.g.dart';

/// A file attached to a message: a photo or a voice note.
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

    /// Voice note loudness, `kVoiceWaveformBars` values 0–100, measured
    /// while recording.
    List<int>? waveform,

    /// Content type, e.g. `audio/mp4` for a voice note.
    String? mime,
  }) = _MessageAttachment;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) =>
      _$MessageAttachmentFromJson(json);
}
