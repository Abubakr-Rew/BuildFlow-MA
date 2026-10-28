import 'package:buildflow/features/chat/domain/chat_search.dart';
import 'package:buildflow/features/chat/domain/chat_timeline.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

Message _m(
  String id,
  String sender,
  DateTime at, {
  MessageKind kind = MessageKind.text,
}) =>
    Message(
      id: id,
      clientId: id,
      chatId: 'c',
      senderId: sender,
      kind: kind,
      text: id,
      createdAt: at,
    );

Chat _chat(String id, ChatType type, String title) => Chat(
      id: id,
      type: type,
      participantIds: const [],
      updatedAt: DateTime(2026),
      title: title,
    );

void main() {
  group('buildTimeline', () {
    final day1 = DateTime(2026, 10, 27, 9);
    final day2 = DateTime(2026, 10, 28, 9);

    List<String> describe(List<TimelineItem> items) => [
          for (final item in items)
            switch (item) {
              DayDivider(:final day) => 'day ${day.day}',
              MessageEntry(:final message, :final firstInGroup, :final lastInGroup) =>
                '${message.id} ${firstInGroup ? 'F' : '-'}${lastInGroup ? 'L' : '-'}',
            },
        ];

    test('puts a divider before each day and groups one author', () {
      final items = buildTimeline([
        _m('a1', 'a', day1),
        _m('a2', 'a', day1.add(const Duration(minutes: 3))),
        _m('b1', 'b', day1.add(const Duration(minutes: 4))),
        _m('b2', 'b', day2),
      ]);
      expect(describe(items), [
        'day 27',
        'a1 F-',
        'a2 -L',
        'b1 FL',
        'day 28',
        'b2 FL',
      ]);
    });

    test('a long pause or a system message breaks a group', () {
      final items = buildTimeline([
        _m('a1', 'a', day1),
        _m('a2', 'a', day1.add(const Duration(minutes: 11))),
        _m('s', 'system', day1.add(const Duration(minutes: 12)),
            kind: MessageKind.system),
        _m('a3', 'a', day1.add(const Duration(minutes: 13))),
      ]);
      expect(describe(items), ['day 27', 'a1 FL', 'a2 FL', 's FL', 'a3 FL']);
    });

    test('is empty without messages', () {
      expect(buildTimeline(const []), isEmpty);
    });
  });

  group('searchChats', () {
    final chats = [
      _chat('p1', ChatType.project, 'ЖК «Ала-Тоо Резиденс»'),
      _chat('p2', ChatType.project, 'Коттеджный посёлок «Горный»'),
      _chat('d1', ChatType.direct, 'Бакыт Касымов'),
    ];

    test('finds a project by a word inside quotes', () {
      final found = searchChats(chats, 'ала');
      expect(found.single.chat.id, 'p1');
      expect(found.single.ranges, [(start: 4, end: 7)]);
    });

    test('finds a person by surname, Latin too', () {
      expect(searchChats(chats, 'kasym').single.chat.id, 'd1');
      expect(searchChats(chats, 'поселок').single.chat.id, 'p2');
    });

    test('filters by type, a blank query matches all', () {
      expect(searchChats(chats, '').map((m) => m.chat.id), ['p1', 'p2', 'd1']);
      expect(
        searchChats(chats, ' ', type: ChatType.direct).map((m) => m.chat.id),
        ['d1'],
      );
    });
  });

  test('Chat and Message survive a JSON round-trip', () {
    final message = Message(
      id: 'm1',
      clientId: 'c1',
      chatId: 'chat-1',
      senderId: 'u1',
      kind: MessageKind.photo,
      createdAt: DateTime.utc(2026, 10, 28, 9),
      status: MessageStatus.read,
      attachments: const [
        MessageAttachment(id: 'a1', url: 'https://x/1.jpg', width: 4, height: 3),
      ],
    );
    final chat = Chat(
      id: 'chat-1',
      type: ChatType.project,
      participantIds: const ['u1', 'u2'],
      updatedAt: DateTime.utc(2026, 10, 28, 9),
      projectId: 'project-1',
      title: 'Объект',
      lastMessage: message,
      unreadCount: 2,
    );
    expect(Chat.fromJson(chat.toJson()), chat);
    expect(chat.toJson()['lastMessage'], isA<Map<String, dynamic>>());
  });

  test('peerOf gives the other person of a direct chat only', () {
    final direct = Chat(
      id: 'd',
      type: ChatType.direct,
      participantIds: const ['a', 'b'],
      updatedAt: DateTime(2026),
    );
    expect(direct.peerOf('a'), 'b');
    expect(direct.copyWith(type: ChatType.project).peerOf('a'), isNull);
  });
}
