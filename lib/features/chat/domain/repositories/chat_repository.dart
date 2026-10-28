import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';

/// How many messages `watchMessages` and `loadOlder` return at most.
const chatPageSize = 50;

/// Longest text message, in characters.
const maxMessageLength = 4000;

/// `Message.senderId` of system messages, written by the server.
const systemSenderId = 'system';

/// Chats of the current user (docs/api-contract.md, «Чат»).
///
/// Never throws. The futures return [Result]; the streams end a failure as
/// an error event carrying a `Failure` (e.g. `forbidden` once the user is
/// removed from the chat), which lands in `AsyncValue.error`.
abstract class ChatRepository {
  /// The user's chats, updated live: new messages, unread counters,
  /// chats added or removed.
  Stream<List<Chat>> watchChats();

  /// The latest [chatPageSize] messages of the chat, oldest first,
  /// updated live.
  Stream<List<Message>> watchMessages(String chatId);

  /// Up to [chatPageSize] messages older than the message [before],
  /// oldest first. Fewer means the history has no more.
  Future<Result<List<Message>>> loadOlder(
    String chatId, {
    required String before,
  });

  /// Sends a text message. Idempotent by [clientId]: a retry returns the
  /// message created by the first attempt.
  Future<Result<Message>> send(
    String chatId, {
    required String text,
    required String clientId,
  });

  /// The direct chat with [userId], created on first use. Only within the
  /// company; never with oneself.
  Future<Result<Chat>> getOrCreateDirect(String userId);

  /// Marks the messages up to and including [upTo] as read.
  Future<Result<void>> markRead(String chatId, {required String upTo});
}
