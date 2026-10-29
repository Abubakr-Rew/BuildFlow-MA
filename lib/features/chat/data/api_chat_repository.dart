import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:flutter/foundation.dart';

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
  Future<Result<MessageAttachment>> uploadPhoto(
    CompressedPhoto photo, {
    ValueChanged<double>? onProgress,
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<MessageAttachment>> uploadVoice(
    VoiceNote note, {
    ValueChanged<double>? onProgress,
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<void>> markListened(
    String chatId, {
    required String messageId,
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  }) async =>
      const Err(_notImplemented);

  @override
  Future<Result<Chat>> getOrCreateDirect(String userId) async =>
      const Err(_notImplemented);

  @override
  Future<Result<void>> markRead(String chatId, {required String upTo}) async =>
      const Err(_notImplemented);
}
