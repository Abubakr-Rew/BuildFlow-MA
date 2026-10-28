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

  /// The content of [message] in one line: its text, the wording of a
  /// system event, or «Неподдерживаемое сообщение».
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
    return message.text ?? '';
  }

  /// The last message under the chat title: «Вы: текст» for the user's
  /// own, «Бакыт: текст» in a project chat, just the text in a direct one.
  String chatPreview(Chat chat, String? me, Map<String, String> names) {
    final message = chat.lastMessage;
    if (message == null) return chatNoMessages;
    final summary = messageSummary(message, names);
    if (message.kind == MessageKind.system) return summary;
    if (message.senderId == me) return '$you: $summary';
    if (chat.type.isProject) {
      final name = memberName(names, message.senderId);
      return '${name.split(' ').first}: $summary';
    }
    return summary;
  }
}
