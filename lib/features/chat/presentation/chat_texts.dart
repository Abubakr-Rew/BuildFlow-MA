import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';

/// How chat texts read in the UI. `names` maps user ids to member names;
/// someone missing from it is no longer in the company.
extension ChatTexts on AppLocalizations {
  /// Name of a user, or «Бывший сотрудник».
  String memberName(Map<String, String> names, String userId) =>
      names[userId] ?? formerMember;

  /// Title of a chat: the project name, the other person's name, or
  /// «Бывший сотрудник» for someone who left.
  String chatTitle(Chat chat) =>
      chat.title.isEmpty && chat.type.isDirect ? formerMember : chat.title;

  /// The content of [message] in one line: its text, «3 фото · подпись»
  /// for photos, the wording of a system event, or «Неподдерживаемое
  /// сообщение».
  String messageSummary(Message message, Map<String, String> names) {
    if (message.kind == MessageKind.system) {
      final name = memberName(names, message.subjectUserId ?? '');
      return switch (message.systemEvent) {
        ChatSystemEvent.memberAdded => systemMemberAdded(name),
        ChatSystemEvent.memberRemoved => systemMemberRemoved(name),
        null => unsupportedMessage,
      };
    }
    if (!message.kind.isSupported) return unsupportedMessage;
    if (message.kind == MessageKind.photo) {
      final count = message.attachments.length;
      final label = count <= 1 ? photoMessage : photosCount(count);
      final caption = message.text?.trim() ?? '';
      return caption.isEmpty ? label : '$label · $caption';
    }
    return message.text ?? '';
  }

  /// The last message under the chat title: «Вы: текст» for the user's
  /// own, «Бакыт: текст» in a project chat, just the text in a direct one.
  /// `isPhoto` puts a photo icon between the prefix and the text.
  ({String prefix, String text, bool isPhoto}) chatPreview(
    Chat chat,
    String? me,
    Map<String, String> names,
  ) {
    final message = chat.lastMessage;
    if (message == null) return (prefix: '', text: chatNoMessages, isPhoto: false);
    final summary = messageSummary(message, names);
    final isPhoto = message.kind == MessageKind.photo;
    if (message.kind == MessageKind.system) {
      return (prefix: '', text: summary, isPhoto: false);
    }
    final prefix = switch (message.senderId) {
      final id when id == me => '$you: ',
      final id when chat.type.isProject =>
        '${memberName(names, id).split(' ').first}: ',
      _ => '',
    };
    return (prefix: prefix, text: summary, isPhoto: isPhoto);
  }
}
