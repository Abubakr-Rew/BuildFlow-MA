import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';

/// Fake chat repository of one signed-in user over the shared
/// [FakeChatStore], with simulated latency.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    required this.store,
    required this.userId,
    required this.sendFailureRate,
    Random? random,
  }) : _random = random ?? Random();

  final FakeChatStore store;

  /// The signed-in user; `null` without a session.
  final String? userId;

  /// Share of sends that fail with a network error, to try the retry
  /// flow on a device (`kFakeChatSendFailureRate`).
  final double sendFailureRate;
  final Random _random;

  static const _noSession =
      Failure(FailureCode.sessionExpired, message: 'Not signed in');

  Future<void> _simulateLatency() async {
    final ms = 200 + _random.nextInt(400);
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  @override
  Stream<List<Chat>> watchChats() {
    final uid = userId;
    if (uid == null) return Stream.error(_noSession);
    return Stream.fromFuture(_simulateLatency())
        .asyncExpand((_) => store.watchChats(uid));
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    final uid = userId;
    if (uid == null) return Stream.error(_noSession);
    return Stream.fromFuture(_simulateLatency())
        .asyncExpand((_) => store.watchMessages(chatId, uid));
  }

  @override
  Future<Result<List<Message>>> loadOlder(
    String chatId, {
    required String before,
  }) async {
    await _simulateLatency();
    final uid = userId;
    if (uid == null) return const Err(_noSession);
    return store.loadOlder(chatId, uid, before: before);
  }

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String text,
    required String clientId,
  }) async {
    await _simulateLatency();
    final uid = userId;
    if (uid == null) return const Err(_noSession);
    if (sendFailureRate > 0 && _random.nextDouble() < sendFailureRate) {
      return const Err(
        Failure(FailureCode.network, message: 'Simulated send failure'),
      );
    }
    return store.send(chatId, uid, text: text, clientId: clientId);
  }

  @override
  Future<Result<Chat>> getOrCreateDirect(String userId) async {
    await _simulateLatency();
    final uid = this.userId;
    if (uid == null) return const Err(_noSession);
    return store.getOrCreateDirect(uid, userId);
  }

  @override
  Future<Result<void>> markRead(String chatId, {required String upTo}) async {
    await _simulateLatency();
    final uid = userId;
    if (uid == null) return const Err(_noSession);
    return store.markRead(chatId, uid, upTo: upTo);
  }
}
