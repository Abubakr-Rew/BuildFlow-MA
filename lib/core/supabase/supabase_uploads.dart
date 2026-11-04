import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:flutter/foundation.dart';

/// An attachment stored in Supabase Storage, not yet attached to a
/// message or report.
@immutable
class UploadedFile {
  const UploadedFile({required this.attachmentId, required this.ref});

  final String attachmentId;
  final StorageRef ref;
}

/// Uploads of photos and voice notes (`POST /uploads` of the contract):
/// `create_upload` reserves the attachment and its path, then the file
/// goes to Storage with progress. The attachment then goes into
/// `send_message` or `submit_report` by id.
///
/// A file uploaded once isn't uploaded again: a retried report or message
/// reuses the attachment of the same local file. A broken upload is
/// retried into the attachment already reserved for it.
class SupabaseUploads {
  SupabaseUploads(this.gateway, {this.onUploaded});

  final SupabaseGateway gateway;

  /// Called with each uploaded file and its local copy, e.g. to keep the
  /// copy as the cached download (`RemoteFiles.adopt`).
  final Future<void> Function(StorageRef ref, String localPath)? onUploaded;

  final Map<String, UploadedFile> _reserved = {};
  final Map<String, UploadedFile> _done = {};

  /// A compressed photo (JPEG).
  Future<Result<UploadedFile>> photo(
    CompressedPhoto photo, {
    ValueChanged<double>? onProgress,
  }) => _upload(
    photo.path,
    contentType: 'image/jpeg',
    params: {
      'p_content_type': 'image/jpeg',
      'p_bytes': photo.bytes,
      'p_width': photo.width,
      'p_height': photo.height,
    },
    onProgress: onProgress,
  );

  /// A recorded voice note (AAC in M4A) with its length and waveform.
  Future<Result<UploadedFile>> voice(
    VoiceNote note, {
    required int bytes,
    ValueChanged<double>? onProgress,
  }) => _upload(
    note.path,
    contentType: VoiceNote.mime,
    params: {
      'p_content_type': VoiceNote.mime,
      'p_bytes': bytes,
      'p_duration_ms': note.duration.inMilliseconds,
      'p_waveform': note.waveform,
    },
    onProgress: onProgress,
  );

  Future<Result<UploadedFile>> _upload(
    String localPath, {
    required String contentType,
    required Map<String, dynamic> params,
    ValueChanged<double>? onProgress,
  }) async {
    final done = _done[localPath];
    if (done != null) {
      onProgress?.call(1);
      return Success(done);
    }

    final reserved = _reserved[localPath];
    final created = reserved != null
        ? Success(reserved)
        : await gateway.rpc('create_upload', (json) {
            final map = json! as Map<String, dynamic>;
            return UploadedFile(
              attachmentId: map['attachmentId'] as String,
              ref: StorageRef(map['bucket'] as String, map['path'] as String),
            );
          }, params: params);
    if (created case Err(:final failure)) return Err(failure);
    final file = _reserved[localPath] = created.value;

    final uploaded = await gateway.upload(
      bucket: file.ref.bucket,
      path: file.ref.path,
      filePath: localPath,
      contentType: contentType,
      onProgress: onProgress,
    );
    if (uploaded case Err(:final failure)) return Err(failure);

    _done[localPath] = file;
    await onUploaded?.call(file.ref, localPath);
    return Success(file);
  }
}
