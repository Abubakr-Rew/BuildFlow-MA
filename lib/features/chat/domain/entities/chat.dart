import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

@freezed
abstract class Chat with _$Chat {
  const factory Chat({
    required String id,
    required ChatType type,
    required List<String> participantIds,

    /// Last activity: the last message, or when the chat was created.
    required DateTime updatedAt,

    /// The project of a [ChatType.project] chat.
    String? projectId,

    /// The project name from the server. Empty for a direct chat: the
    /// client shows the other person's name instead.
    @Default('') String title,
    Message? lastMessage,

    /// Messages from others the current user hasn't read.
    @Default(0) int unreadCount,
  }) = _Chat;

  const Chat._();

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  /// The other person of a direct chat for [userId].
  String? peerOf(String userId) => type.isDirect
      ? participantIds.where((id) => id != userId).firstOrNull
      : null;
}
