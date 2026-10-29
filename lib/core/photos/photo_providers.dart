import 'dart:async';

import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/photos/lost_capture.dart';
import 'package:buildflow/core/photos/photo_compressor.dart';
import 'package:buildflow/core/photos/photo_draft.dart';
import 'package:buildflow/core/photos/photo_picker.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The one photo compressor of the app; tests override it.
final photoCompressorProvider = Provider<PhotoCompressor>(
  (ref) => const PlatformPhotoCompressor(),
);

/// The system camera and gallery; tests override it.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);

/// A camera shot that came back after Android killed the app under the
/// camera, until its screen takes it. `recover()` runs once after start.
final lostCaptureProvider =
    NotifierProvider<LostCaptureNotifier, LostCapture?>(
  LostCaptureNotifier.new,
);

class LostCaptureNotifier extends Notifier<LostCapture?> {
  @override
  LostCapture? build() => null;

  /// Asks the picker for a shot lost with the app and where it belongs.
  /// A shot with no saved place (e.g. from an older version) is deleted.
  Future<void> recover() async {
    final storage = ref.read(localStorageProvider);
    Map<String, dynamic>? saved;
    LostPhotos lost;
    try {
      saved = await storage.readJson(pendingCaptureKey);
      await storage.remove(pendingCaptureKey);
    } on Exception catch (e) {
      debugPrint('Pending capture unreadable: $e');
    }
    try {
      lost = await ref.read(photoPickerProvider).retrieveLost();
    } on Exception catch (e) {
      debugPrint('Lost photo retrieval failed: $e');
      return;
    }
    if (lost.error != null) debugPrint('Lost photo error: ${lost.error}');
    if (lost.paths.isEmpty) return;

    final target = saved == null ? null : CaptureTarget.fromJson(saved);
    if (target == null) {
      unawaited(ref.read(photoCompressorProvider).delete(lost.paths));
      return;
    }
    state = LostCapture(target: target, paths: lost.paths);
  }

  /// The waiting shot if [belongs] says it's for the caller, once.
  LostCapture? take(bool Function(CaptureTarget target) belongs) {
    final capture = state;
    if (capture == null || !belongs(capture.target)) return null;
    state = null;
    return capture;
  }

  /// Drops the waiting shot and its files, e.g. when someone else signed in.
  void discard() {
    final capture = state;
    if (capture == null) return;
    state = null;
    unawaited(ref.read(photoCompressorProvider).delete(capture.paths));
  }
}

/// Photos picked in one place and being compressed, by scope: one per new
/// report screen, `chat:<id>` for the message field of a chat. Leaving the
/// place drops the photos still there and deletes their files.
final photoDraftsProvider = NotifierProvider.autoDispose
    .family<PhotoDraftsNotifier, List<PhotoDraft>, String>(
  PhotoDraftsNotifier.new,
);

class PhotoDraftsNotifier
    extends AutoDisposeFamilyNotifier<List<PhotoDraft>, String> {
  static const _uuid = Uuid();

  late PhotoCompressor _compressor;

  /// The running or finished compression of every draft still here.
  final Map<String, Future<Result<CompressedPhoto>>> _runs = {};

  /// Drafts removed while compressing: their copy is deleted on arrival.
  final Set<String> _abandoned = {};

  /// Mirrors [state], which can't be read once disposed.
  List<PhotoDraft> _drafts = const [];

  @override
  List<PhotoDraft> build(String scope) {
    _compressor = ref.watch(photoCompressorProvider);
    ref.onDispose(() {
      _abandoned.addAll(_runs.keys);
      _runs.clear();
      unawaited(_compressor.delete(_filesOf(_drafts)));
    });
    return _drafts = const [];
  }

  void _set(List<PhotoDraft> drafts) => state = _drafts = drafts;

  /// Adds picked photos and starts compressing them, one after another.
  void add(Iterable<String> paths) {
    final added = [
      for (final path in paths) PhotoDraft(id: _uuid.v4(), sourcePath: path),
    ];
    if (added.isEmpty) return;
    _set([..._drafts, ...added]);
    added.forEach(_start);
  }

  void _start(PhotoDraft draft) {
    final run = _compressor.compress(draft.sourcePath);
    _runs[draft.id] = run;
    unawaited(
      run.then((result) {
        if (_abandoned.remove(draft.id)) {
          if (result case Success(:final data)) {
            unawaited(_compressor.delete([data.path]));
          }
          return;
        }
        // Retried meanwhile, or handed over: someone else has the result.
        if (_runs[draft.id] != run) return;
        _set([
          for (final d in _drafts)
            if (d.id != draft.id)
              d
            else
              switch (result) {
                Success(:final data) =>
                  PhotoDraft(id: d.id, sourcePath: d.sourcePath, photo: data),
                Err(:final failure) => PhotoDraft(
                    id: d.id,
                    sourcePath: d.sourcePath,
                    failure: failure,
                  ),
              },
        ]);
      }),
    );
  }

  /// Compresses a failed photo again from its original.
  void retry(String id) {
    final draft = _drafts.where((d) => d.id == id).firstOrNull;
    if (draft == null || !draft.isFailed) return;
    final again = PhotoDraft(id: id, sourcePath: draft.sourcePath);
    _set([
      for (final d in _drafts)
        if (d.id == id) again else d,
    ]);
    _start(again);
  }

  /// Drops a photo and deletes its files.
  void remove(String id) {
    final draft = _drafts.where((d) => d.id == id).firstOrNull;
    if (draft == null) return;
    if (draft.isProcessing) _abandoned.add(id);
    _runs.remove(id);
    _set([for (final d in _drafts) if (d.id != id) d]);
    unawaited(_compressor.delete(_filesOf([draft])));
  }

  /// Hands every photo over, e.g. to a chat message on its way, and empties
  /// the list. The receiver owns the files from now on.
  List<PhotoHandoff> takeAll() {
    final handoffs = [
      for (final d in _drafts)
        (draft: d, result: _runs[d.id] ?? Future.value(Success(d.photo!))),
    ];
    _runs.clear();
    _set(const []);
    return handoffs;
  }

  /// The compressed copies of every photo here, in order, once all are
  /// done; or the first failure.
  Future<Result<List<CompressedPhoto>>> whenReady() async {
    final photos = <CompressedPhoto>[];
    for (final draft in List.of(_drafts)) {
      final run = _runs[draft.id];
      if (run == null) continue;
      switch (await run) {
        case Success(:final data):
          photos.add(data);
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Success(photos);
  }

  /// Forgets the photos after they were sent: the originals are deleted,
  /// the copies now belong to what was sent.
  void clear() {
    final originals = [for (final d in _drafts) d.sourcePath];
    _runs.clear();
    _set(const []);
    unawaited(_compressor.delete(originals));
  }

  static List<String> _filesOf(Iterable<PhotoDraft> drafts) => [
        for (final d in drafts) ...[
          d.sourcePath,
          if (d.photo case final photo?) photo.path,
        ],
      ];
}
