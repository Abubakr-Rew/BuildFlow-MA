import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:flutter/foundation.dart';

/// How many messages `watchMessages` and `loadOlder` return at most.
const chatPageSize = 50;

/// Longest text message or photo caption, in characters.
const maxMessageLength = 4000;

/// Most photos in one message.
const maxPhotosPerMessage = 10;

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

  /// Uploads a compressed photo for a message, reporting [onProgress]
  /// from 0 to 1. The attachment's id then goes into [send]; it belongs to
  /// the uploader and can be attached once.
  Future<Result<MessageAttachment>> uploadPhoto(
    CompressedPhoto photo, {
    ValueChanged<double>? onProgress,
  });

  /// Uploads a recorded voice note, reporting [onProgress] from 0 to 1;
  /// the attachment carries its length and waveform. Like a photo, it
  /// belongs to the uploader and can be attached once.
  Future<Result<MessageAttachment>> uploadVoice(
    VoiceNote note, {
    ValueChanged<double>? onProgress,
  });

  /// Sends a message: [text]; photos uploaded by [uploadPhoto] with [text]
  /// as their optional caption; or one voice note from [uploadVoice].
  /// Idempotent by [clientId]: a retry returns the message created by the
  /// first attempt.
  Future<Result<Message>> send(
    String chatId, {
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  });

  /// The direct chat with [userId], created on first use. Only within the
  /// company; never with oneself.
  Future<Result<Chat>> getOrCreateDirect(String userId);

  /// Marks the voice note [messageId] as played by the user.
  Future<Result<void>> markListened(String chatId, {required String messageId});

  /// Marks the messages up to and including [upTo] as read.
  Future<Result<void>> markRead(String chatId, {required String upTo});
}
