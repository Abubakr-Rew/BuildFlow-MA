import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';

/// API chat repository skeleton. Selected when `kUseMockData` is false;
/// every call fails until the backend is available. REST and the STOMP
/// events are described in docs/api-contract.md («Чат»).
class ApiChatRepository implements ChatRepository {
  static const _notImplemented =
      Failure(FailureCode.server, message: 'API not implemented');

  @override
  Stream<List<Chat>> watchChats() => Stream.error(_notImplemented);

  @override
  Stream<List<Message>> watchMessages(String chatId) =>
      Stream.error(_notImplemented);

  @override
  Future<Result<List<Message>>> loadOlder(
    String chatId, {
    required String before,
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String text,
    required String clientId,
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<Chat>> getOrCreateDirect(String userId) async =>
      const Err(_notImplemented);

  @override
  Future<Result<void>> markRead(String chatId, {required String upTo}) async =>
      const Err(_notImplemented);
}
