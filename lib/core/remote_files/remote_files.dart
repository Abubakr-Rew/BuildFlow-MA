import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Files of reports and messages kept in Supabase Storage, on the phone.
///
/// The buckets are private: a file is reached through a signed link of
/// [linkLifetime], which is cached by attachment id and signed again
/// shortly before it expires, or when a download says it has. Links asked
/// for within [signBatchDelay] (the photos of one screen) are signed with
/// one request per bucket.
///
/// Downloaded files live in `cacheDir/remote/<attachmentId>.<ext>`: photos
/// are shown and voice notes played from there. The user's own uploads are
/// [adopt]ed, so they never download again. [clear] on sign-out and when
/// the user changes; [sweep] after start.
class RemoteFiles {
  RemoteFiles({
    this.gateway,
    Future<String> Function()? cacheDir,
    DateTime Function()? now,
  })  : _cacheDir = cacheDir ?? _platformCacheDir,
        _now = now ?? DateTime.now;

  /// `null` with the fake backend, which has no `storage:` files.
  final SupabaseGateway? gateway;
  final Future<String> Function() _cacheDir;
  final DateTime Function() _now;

  static const linkLifetime = Duration(hours: 1);

  /// A link this close to its end is signed again before use.
  static const linkMargin = Duration(minutes: 5);

  /// How long a link waits for others to be signed with it.
  static const signBatchDelay = Duration(milliseconds: 10);

  static const _paths = MethodChannel('buildflow/paths');

  static Future<String> _platformCacheDir() async =>
      (await _paths.invokeMethod<String>('cacheDir'))!;

  final Map<String, ({String url, DateTime expires})> _links = {};
  final Map<String, Future<Result<String>>> _downloads = {};

  /// Links waiting to be signed together, by bucket and path.
  final Map<String, Map<String, Completer<Result<String>>>> _toSign = {};
  Timer? _signTimer;
  Future<String>? _dirPath;

  /// Bumped by [clear]: work started before it doesn't write into the
  /// cache of the next user.
  int _generation = 0;

  /// The file of [ref] on the phone, downloaded first if needed.
  Future<Result<String>> localPath(StorageRef ref) {
    final key = ref.attachmentId;
    return _downloads[key] ??= _localPath(ref).whenComplete(
      // A block: whenComplete would wait for the removed future, itself.
      () {
        _downloads.remove(key);
      },
    );
  }

  Future<Result<String>> _localPath(StorageRef ref) async {
    final generation = _generation;
    final String file;
    try {
      file = await _fileOf(ref);
      if (File(file).existsSync()) {
        // Recently used: [sweep] deletes the least recently used first.
        unawaited(_touch(file));
        return Success(file);
      }
    } on Object catch (e, stackTrace) {
      return Err(
        Failure(FailureCode.unknown, message: '$e', stackTrace: stackTrace),
      );
    }

    var downloaded = await _download(ref, file, generation);
    // An expired or revoked link: sign again once.
    if (downloaded case Err(:final failure)
        when _isLinkRefused(failure.statusCode)) {
      _links.remove(ref.attachmentId);
      downloaded = await _download(ref, file, generation);
    }
    return downloaded.when(
      success: (_) => Success(file),
      failure: Err.new,
    );
  }

  Future<Result<void>> _download(
    StorageRef ref,
    String file,
    int generation,
  ) async {
    final link = await signedUrl(ref);
    if (link case Err(:final failure)) return Err(failure);
    final gateway = this.gateway!;
    final part = '$file.${identityHashCode(ref)}.part';
    final result = await gateway.download(link.value, part);
    try {
      if (result.isSuccess && generation == _generation) {
        await File(part).rename(file);
      } else if (File(part).existsSync()) {
        await File(part).delete();
      }
    } on FileSystemException catch (e, stackTrace) {
      return Err(
        Failure(FailureCode.unknown, message: '$e', stackTrace: stackTrace),
      );
    }
    return result;
  }

  /// A link to [ref] valid for a while yet, signed if needed.
  Future<Result<String>> signedUrl(StorageRef ref) {
    if (gateway == null) {
      return Future.value(
        Err(Failure(FailureCode.unknown, message: 'No storage for $ref')),
      );
    }
    final cached = _links[ref.attachmentId];
    if (cached != null && _now().isBefore(cached.expires.subtract(linkMargin))) {
      return Future.value(Success(cached.url));
    }
    final waiting = _toSign.putIfAbsent(ref.bucket, () => {});
    final completer = waiting[ref.path] ??= Completer<Result<String>>();
    _signTimer ??= Timer(signBatchDelay, _signWaiting);
    return completer.future;
  }

  Future<void> _signWaiting() async {
    _signTimer = null;
    final batches = Map.of(_toSign);
    _toSign.clear();
    final signedAt = _now();
    await Future.wait([
      for (final MapEntry(key: bucket, value: waiting) in batches.entries)
        gateway!
            .signUrls(bucket, waiting.keys.toList(), expiresIn: linkLifetime)
            .then((result) {
          for (final MapEntry(key: path, value: completer)
              in waiting.entries) {
            final ref = StorageRef(bucket, path);
            final reply = switch (result) {
              Success(value: final links) when links[path] != null =>
                Success(links[path]!),
              Success() => Err<String>(
                  Failure(FailureCode.notFound, message: 'Not signed: $ref'),
                ),
              Err(:final failure) => Err<String>(failure),
            };
            if (reply case Success(:final value)) {
              _links[ref.attachmentId] = (
                url: value,
                expires: signedAt.add(linkLifetime),
              );
            }
            completer.complete(reply);
          }
        }),
    ]);
  }

  /// Keeps [localPath] (the user's own upload) as the cached file of
  /// [ref]: it's what the server has. Best effort.
  Future<void> adopt(StorageRef ref, String localPath) async {
    try {
      final file = await _fileOf(ref);
      if (!File(file).existsSync()) {
        await File(file).parent.create(recursive: true);
        await File(localPath).copy(file);
      }
    } on Object catch (e) {
      debugPrint('Keeping the upload $ref failed: $e');
    }
  }

  /// Forgets every link and file: on sign-out and when the user changes.
  /// Clears run one after another, never over each other.
  Future<void> clear() {
    _generation++;
    _links.clear();
    _downloads.clear();
    return _clearing = _clearing.then((_) => _deleteAll());
  }

  Future<void> _clearing = Future.value();

  Future<void> _deleteAll() async {
    try {
      final dir = Directory(await _dir());
      if (dir.existsSync()) await dir.delete(recursive: true);
    } on Object catch (e) {
      debugPrint('Clearing downloaded files failed: $e');
    }
  }

  /// Deletes files unused for [maxAge], then the least recently used ones
  /// over [maxBytes]. Called once after start.
  Future<void> sweep({
    Duration maxAge = const Duration(days: 30),
    int maxBytes = 300 * 1024 * 1024,
  }) async {
    try {
      final dir = Directory(await _dir());
      if (!dir.existsSync()) return;
      final files = [
        for (final entity in dir.listSync())
          if (entity is File) (file: entity, stat: entity.statSync()),
      ]..sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
      final oldest = _now().subtract(maxAge);
      var kept = 0;
      for (final (:file, :stat) in files) {
        kept += stat.size;
        if (stat.modified.isBefore(oldest) ||
            kept > maxBytes ||
            file.path.endsWith('.part')) {
          await file.delete();
        }
      }
    } on Object catch (e) {
      debugPrint('Sweeping downloaded files failed: $e');
    }
  }

  Future<String> _dir() =>
      _dirPath ??= _cacheDir().then((cache) => '$cache/remote');

  Future<void> _touch(String file) async {
    try {
      await File(file).setLastModified(_now());
    } on FileSystemException catch (_) {}
  }

  /// Where [ref] is kept; the folder is made when a file is written.
  Future<String> _fileOf(StorageRef ref) async {
    final dir = await _dir();
    final ext = ref.extension;
    return ext.isEmpty
        ? '$dir/${ref.attachmentId}'
        : '$dir/${ref.attachmentId}.$ext';
  }

  /// Storage refuses an expired or otherwise bad link with 400, 401 or 403.
  static bool _isLinkRefused(int? status) =>
      status == 400 || status == 401 || status == 403;
}
