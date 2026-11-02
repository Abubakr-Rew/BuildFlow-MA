import 'package:buildflow/features/chat/data/chat_events.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const message = {
    'id': 'm1',
    'clientId': 'c-m1',
    'chatId': 'c1',
    'senderId': 'system',
    'kind': 'system',
    'text': null,
    'createdAt': '2026-11-02T10:00:00Z',
    'status': 'sent',
    'attachments': <Object>[],
    'listened': false,
    'reportId': null,
    'systemEvent': 'memberAdded',
    'subjectUserId': 'u5',
  };

  test('the events of the contract, as the database sends them', () {
    final created = ChatEvent.fromJson({
      'type': 'message.created',
      'chatId': 'c1',
      'message': message,
      'id': 'realtime-id',
    });
    expect(
      created,
      isA<MessageCreated>()
          .having((e) => e.message.systemEvent, 'event', ChatSystemEvent.memberAdded),
    );

    expect(
      ChatEvent.fromJson({'type': 'message.status', 'chatId': 'c1', 'upTo': 'm1', 'status': 'read'}),
      isA<MessagesRead>().having((e) => e.upTo, 'upTo', 'm1'),
    );
    expect(
      ChatEvent.fromJson({'type': 'message.listened', 'chatId': 'c1', 'messageId': 'm1', 'userId': 'u2'}),
      isA<MessageListened>(),
    );
    expect(
      ChatEvent.fromJson({
        'type': 'chat.updated',
        'chat': {
          'id': 'c1',
          'type': 'direct',
          'projectId': null,
          'title': '',
          'participantIds': ['u1', 'u2'],
          'updatedAt': '2026-11-02T10:00:00Z',
          'unreadCount': 2,
          'lastMessage': message,
        },
      }),
      isA<ChatUpdated>().having((e) => e.chat.unreadCount, 'unread', 2),
    );
    expect(
      ChatEvent.fromJson({'type': 'chat.removed', 'chatId': 'c1'}),
      isA<ChatRemoved>(),
    );
  });

  test('an event this version does not know is skipped', () {
    expect(ChatEvent.fromJson({'type': 'report.created'}), isNull);
  });
}
