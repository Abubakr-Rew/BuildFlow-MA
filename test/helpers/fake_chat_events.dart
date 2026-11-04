import 'dart:async';

import 'package:buildflow/features/chat/data/chat_events.dart';

/// A realtime channel the test drives: [emit] events, [drop] the channel,
/// [rejoin] it. Counts what the repository asked of it.
class FakeChatEvents implements ChatEvents {
  final _events = StreamController<ChatEvent>.broadcast();
  final _rejoined = StreamController<void>.broadcast();

  bool joined = false;
  int connects = 0;
  int reconnects = 0;
  bool disposed = false;

  /// Whether [reconnect] joins right away (and fires [rejoined]).
  bool reconnectJoins = true;

  void emit(ChatEvent event) => _events.add(event);

  /// The connection drops; events now are lost.
  void drop() => joined = false;

  /// The channel is back after a drop.
  void rejoin() {
    joined = true;
    _rejoined.add(null);
  }

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Stream<void> get rejoined => _rejoined.stream;

  @override
  bool get isJoined => joined;

  @override
  void connect() {
    connects++;
    joined = true;
  }

  @override
  Future<void> reconnect() async {
    reconnects++;
    if (reconnectJoins) rejoin();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    joined = false;
    await _events.close();
    await _rejoined.close();
  }
}
