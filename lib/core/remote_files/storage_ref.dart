import 'package:flutter/foundation.dart';

/// A file in a Supabase Storage bucket, written into `url` fields as
/// `storage:<bucket>/<path>`. The server sends `bucket` and `path` of an
/// attachment instead of a link (docs/supabase-plan.md); the app signs and
/// downloads it when shown (`RemoteFiles`).
@immutable
class StorageRef {
  const StorageRef(this.bucket, this.path);

  static const scheme = 'storage:';

  /// `storage:photos/c1/u1/a1.jpg` → `photos`, `c1/u1/a1.jpg`; `null` for
  /// any other URL (`fake:`, a local file, http).
  static StorageRef? tryParse(String url) {
    if (!url.startsWith(scheme)) return null;
    final rest = url.substring(scheme.length);
    final slash = rest.indexOf('/');
    if (slash <= 0 || slash == rest.length - 1) return null;
    return StorageRef(rest.substring(0, slash), rest.substring(slash + 1));
  }

  final String bucket;

  /// `{company_id}/{user_id}/{attachment_id}.{ext}`.
  final String path;

  /// The attachment the file belongs to: the file name without extension.
  String get attachmentId {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// `jpg`, `m4a`…, or empty.
  String get extension {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(dot + 1) : '';
  }

  String get url => '$scheme$bucket/$path';

  @override
  bool operator ==(Object other) =>
      other is StorageRef && other.bucket == bucket && other.path == path;

  @override
  int get hashCode => Object.hash(bucket, path);

  @override
  String toString() => url;
}

/// `readValue` of an attachment's `url`: the JSON's own `url` (the fake
/// data, local files), or `storage:<bucket>/<path>` built from the
/// server's `bucket` and `path`.
Object? readStorageUrl(Map<dynamic, dynamic> json, String key) =>
    json[key] ??
    switch ((json['bucket'], json['path'])) {
      (final String bucket, final String path) => StorageRef(bucket, path).url,
      _ => null,
    };
