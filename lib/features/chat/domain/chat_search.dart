import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/team/domain/member_search.dart';

/// A chat found by [searchChats] with the matched parts of its title.
typedef ChatMatch = ({Chat chat, List<MatchRange> ranges});

/// Quotes and punctuation, read as spaces so that «ала» finds
/// «ЖК «Ала-Тоо Резиденс»». One character for one: ranges stay valid.
final _punctuation = RegExp(r'[«»"„“()\[\].,:;!?№]');

/// Where [query] matches a chat [title], by the people-search rules of
/// [matchName] (start of any word, ё = е, Latin read as Cyrillic).
List<MatchRange>? matchChatTitle(String title, String query) =>
    matchName(title.replaceAll(_punctuation, ' '), query);

/// [chats] of [type] (all types for `null`) whose title matches [query],
/// in the given order. Titles of direct chats must already be filled in.
List<ChatMatch> searchChats(
  Iterable<Chat> chats,
  String query, {
  ChatType? type,
}) =>
    [
      for (final chat in chats)
        if (type == null || chat.type == type)
          if (matchChatTitle(chat.title, query.trim()) case final ranges?)
            (chat: chat, ranges: ranges),
    ];
