import 'dart:async';

import 'package:buildflow/core/audio/voice_player.dart';
import 'package:buildflow/core/audio/voice_recorder.dart';

/// [VoiceRecorder] for tests: the test feeds the levels and the
/// interruptions and decides the permission.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permitted = true});

  bool permitted;

  /// Completes the permission dialog when the test says so; `null` answers
  /// at once.
  Completer<bool>? permissionDialog;
  Exception? startError;

  final _levels = StreamController<double>.broadcast();
  final _interruptions = StreamController<void>.broadcast();
  final List<String> calls = [];
  var _count = 0;
  String? _current;

  bool get recording => _current != null;

  void emitLevel(double level) => _levels.add(level);
  void interrupt() => _interruptions.add(null);

  @override
  Future<bool> hasPermission({bool request = true}) async {
    calls.add('permission');
    return permissionDialog?.future ?? permitted;
  }

  @override
  Future<void> start() async {
    calls.add('start');
    if (startError case final error?) throw error;
    _current = '/cache/voice-${++_count}.m4a';
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    final path = _current;
    _current = null;
    return path;
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    _current = null;
  }

  @override
  Stream<double> levels() => _levels.stream;

  @override
  Stream<void> interruptions() => _interruptions.stream;
}

/// [VoicePlayer] for tests: records what it was told to do.
class FakeVoicePlayer implements VoicePlayer {
  final List<String> calls = [];
  final _positions = StreamController<Duration>.broadcast();
  final _completions = StreamController<void>.broadcast();

  void emitPosition(Duration position) => _positions.add(position);
  void complete() => _completions.add(null);

  @override
  Future<void> play(
    String url, {
    required double speed,
    Duration from = Duration.zero,
  }) async =>
      calls.add('play $url ${speed}x ${from.inMilliseconds}');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek ${position.inMilliseconds}');

  @override
  Future<void> setSpeed(double speed) async => calls.add('speed ${speed}x');

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Future<void> dispose() async {}
}
