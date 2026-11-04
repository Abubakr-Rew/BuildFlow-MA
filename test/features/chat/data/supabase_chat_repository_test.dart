import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/chat/data/chat_events.dart';
import 'package:buildflow/features/chat/data/supabase_chat_repository.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_chat_events.dart';
import '../../../helpers/fake_supabase.dart';

const _me = 'u1';

Map<String, dynamic> _message(
  String id, {
  String chat = 'c1',
  String sender = 'u2',
  String kind = 'text',
  String status = 'sent',
  String? clientId,
}) =>
    {
      'id': id,
      'clientId': clientId ?? 'client-$id',
      'chatId': chat,
      'senderId': sender,
      'kind': kind,
      'text': 'text $id',
      'createdAt': '2026-11-02T10:00:00Z',
      'status': status,
      'attachments': <Object>[],
      'listened': false,
      'reportId': null,
      'systemEvent': null,
      'subjectUserId': null,
    };

Map<String, dynamic> _chat(
  String id, {
  String updatedAt = '2026-11-02T10:00:00Z',
  int unread = 0,
  Map<String, dynamic>? lastMessage,
}) =>
    {
      'id': id,
      'type': 'project',
      'projectId': 'p-$id',
      'title': 'Объект $id',
      'participantIds': [_me, 'u2'],
      'updatedAt': updatedAt,
      'unreadCount': unread,
      'lastMessage': lastMessage,
    };

Message _parsed(Map<String, dynamic> json) => Message.fromJson(json);

void main() {
  late FakeSupabase supabase;
  late FakeChatEvents events;
  late SupabaseChatRepository repo;

  setUp(() async {
    supabase = FakeSupabase();
    await supabase.signIn(_me);
    events = FakeChatEvents();
    repo = SupabaseChatRepository(
      gateway: supabase.gateway,
      uploads: SupabaseUploads(supabase.gateway),
      userId: _me,
      events: events,
    );
  });
  tearDown(() async {
    await repo.dispose();
    await supabase.dispose();
  });

  /// `get_messages` answers by its parameters with [answer].
  void messagesAnswer(
    Map<String, dynamic> Function(Map<String, dynamic> params) answer,
  ) =>
      supabase.on(
        'POST',
        '/rest/v1/rpc/get_messages',
        (request) => FakeReply(200, answer(request.json)),
      );

  group('chats', () {
    test('load, then follow chat.updated and chat.removed', () async {
      supabase.rpc('get_chats', [
        _chat('c1', updatedAt: '2026-11-02T09:00:00Z'),
        _chat('c2', updatedAt: '2026-11-02T08:00:00Z'),
      ]);
      final lists = <List<Chat>>[];
      final sub = repo.watchChats().listen(lists.add);
      await pumpEventQueue();
      expect(lists.last.map((c) => c.id), ['c1', 'c2']);
      expect(events.connects, 1);

      // A new message in c2 moves it up with its unread count.
      events.emit(
        ChatUpdated(
          Chat.fromJson(
            _chat('c2', unread: 1),
          ),
        ),
      );
      await pumpEventQueue();
      expect(lists.last.map((c) => c.id), ['c2', 'c1']);
      expect(lists.last.first.unreadCount, 1);

      events.emit(const ChatRemoved('c1'));
      await pumpEventQueue();
      expect(lists.last.map((c) => c.id), ['c2']);
      await sub.cancel();
    });

    test('a failed load is an error of the stream', () async {
      supabase.rpcFails('get_chats', 500, 'oops');

      await expectLater(
        repo.watchChats(),
        emitsError(isA<Failure>().having((f) => f.code, 'code', FailureCode.server)),
      );
    });

    test('a new direct chat joins the list', () async {
      supabase
        ..rpc('get_chats', <Object>[])
        ..rpc('get_or_create_direct', {..._chat('d1'), 'type': 'direct'});
      final lists = <List<Chat>>[];
      final sub = repo.watchChats().listen(lists.add);
      await pumpEventQueue();

      final chat = (await repo.getOrCreateDirect('u2')).value;

      expect(chat.type, ChatType.direct);
      expect(supabase.rpcCalls('get_or_create_direct').single, {'p_user_id': 'u2'});
      await pumpEventQueue();
      expect(lists.last.single.id, 'd1');
      await sub.cancel();
    });
  });

  group('messages', () {
    late List<List<Message>> pages;
    late StreamSubscription<List<Message>> sub;
    final errors = <Object>[];

    Future<void> open() async {
      pages = [];
      errors.clear();
      sub = repo.watchMessages('c1').listen(pages.add, onError: errors.add);
      await pumpEventQueue();
    }

    tearDown(() => sub.cancel());

    test('the latest page, then new messages without duplicates', () async {
      messagesAnswer((_) => {
            'messages': [_message('m1'), _message('m2')],
            'truncated': false,
          });
      await open();
      expect(pages.last.map((m) => m.id), ['m1', 'm2']);
      expect(supabase.rpcCalls('get_messages').single, {
        'p_chat_id': 'c1',
        'p_limit': 50,
      });

      final m3 = MessageCreated(chatId: 'c1', message: _parsed(_message('m3')));
      events
        ..emit(m3)
        ..emit(m3)
        ..emit(MessageCreated(chatId: 'c9', message: _parsed(_message('x'))));
      await pumpEventQueue();

      expect(pages.last.map((m) => m.id), ['m1', 'm2', 'm3']);
    });

    test("others reading marks the user's messages read up to upTo", () async {
      messagesAnswer((_) => {
            'messages': [
              _message('m1', sender: _me),
              _message('m2'),
              _message('m3', sender: _me),
            ],
            'truncated': false,
          });
      await open();

      events.emit(const MessagesRead(chatId: 'c1', upTo: 'm2'));
      await pumpEventQueue();

      expect(
        pages.last.map((m) => '${m.id} ${m.status.name}'),
        ['m1 read', 'm2 sent', 'm3 sent'],
      );
    });

    test('removed from the chat: the stream says forbidden', () async {
      messagesAnswer((_) => {'messages': [_message('m1')], 'truncated': false});
      await open();

      events.emit(const ChatRemoved('c1'));
      await pumpEventQueue();

      expect(errors.single, isA<Failure>().having((f) => f.code, 'code', FailureCode.forbidden));
    });

    test('older pages', () async {
      messagesAnswer((_) => {'messages': [_message('m0')], 'truncated': false});

      final older = (await repo.loadOlder('c1', before: 'm1')).value;

      expect(older.single.id, 'm0');
      expect(supabase.rpcCalls('get_messages').single, {
        'p_chat_id': 'c1',
        'p_before': 'm1',
        'p_limit': 50,
      });
    });
  });

  group('catching up', () {
    test('a rejoined channel reloads the chats and the messages after the last',
        () async {
      supabase.rpc('get_chats', [_chat('c1')]);
      messagesAnswer((params) => {
            'messages': params['p_after'] == null
                ? [_message('m1'), _message('m2')]
                : [_message('m3')],
            'truncated': false,
          });
      final chats = repo.watchChats().listen((_) {});
      final pages = <List<Message>>[];
      final messages = repo.watchMessages('c1').listen(pages.add);
      await pumpEventQueue();

      events
        ..drop()
        ..rejoin();
      await pumpEventQueue();

      expect(supabase.rpcCalls('get_chats'), hasLength(2));
      expect(supabase.rpcCalls('get_messages').last, {
        'p_chat_id': 'c1',
        'p_after': 'm2',
      });
      expect(pages.last.map((m) => m.id), ['m1', 'm2', 'm3']);
      await chats.cancel();
      await messages.cancel();
    });

    test('too much missed: the latest page again', () async {
      var calls = 0;
      messagesAnswer((params) {
        calls++;
        return {
          'messages': calls == 1
              ? [_message('m1')]
              : params['p_after'] != null
                  ? [_message('m600')]
                  : [_message('m551'), _message('m600')],
          'truncated': params['p_after'] != null,
        };
      });
      final pages = <List<Message>>[];
      final sub = repo.watchMessages('c1').listen(pages.add);
      await pumpEventQueue();

      events.rejoin();
      await pumpEventQueue();

      expect(pages.last.map((m) => m.id), ['m551', 'm600']);
      await sub.cancel();
    });

    test('chats that failed to load (started offline) load when back online',
        () async {
      supabase.on(
        'POST',
        '/rest/v1/rpc/get_chats',
        (_) => throw const SocketException('offline'),
      );
      final lists = <List<Chat>>[];
      final errors = <Object>[];
      final sub = repo.watchChats().listen(lists.add, onError: errors.add);
      await pumpEventQueue();
      expect(errors.single, isA<Failure>().having((f) => f.code, 'code', FailureCode.network));

      supabase.rpc('get_chats', [_chat('c1')]);
      events
        ..drop()
        ..rejoin();
      await pumpEventQueue();

      expect(lists.single.single.id, 'c1');
      await sub.cancel();
    });

    group('back from the background', () {
      late StreamSubscription<List<Chat>> chats;
      late StreamSubscription<List<Message>> messages;

      setUp(() async {
        supabase.rpc('get_chats', [_chat('c1')]);
        messagesAnswer((params) => {
              'messages': params['p_after'] == null ? [_message('m1')] : <Object>[],
              'truncated': false,
            });
        chats = repo.watchChats().listen((_) {});
        messages = repo.watchMessages('c1').listen((_) {});
        await pumpEventQueue();
      });
      tearDown(() async {
        await chats.cancel();
        await messages.cancel();
      });

      test('a channel found down is joined again, then caught up', () async {
        events.drop();

        await repo.onAppResumed();
        await pumpEventQueue();

        expect(events.reconnects, 1);
        expect(supabase.rpcCalls('get_chats'), hasLength(2));
        expect(supabase.rpcCalls('get_messages').last['p_after'], 'm1');
      });

      test('a channel still up is caught up without rejoining', () async {
        await repo.onAppResumed();

        expect(events.reconnects, 0);
        expect(supabase.rpcCalls('get_chats'), hasLength(2));
        expect(supabase.rpcCalls('get_messages').last['p_after'], 'm1');
      });

      test('a channel that stays down catches up once it is back', () async {
        events
          ..drop()
          ..reconnectJoins = false;

        await repo.onAppResumed();
        await pumpEventQueue();
        expect(supabase.rpcCalls('get_chats'), hasLength(1));

        events.rejoin();
        await pumpEventQueue();
        expect(supabase.rpcCalls('get_chats'), hasLength(2));
      });
    });
  });

  group('sending', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('chat_repo_test');
      supabase
        ..on('POST', '/rest/v1/rpc/create_upload', (request) {
          final voice = request.json['p_content_type'] == 'audio/mp4';
          return FakeReply(200, {
            'attachmentId': voice ? 'v1' : 'a1',
            'bucket': voice ? 'voice' : 'photos',
            'path': voice ? 'c/u1/v1.m4a' : 'c/u1/a1.jpg',
          });
        })
        ..on('POST', '/storage/v1/object/photos/c/u1/a1.jpg', (_) => const FakeReply(200, {}))
        ..on('POST', '/storage/v1/object/voice/c/u1/v1.m4a', (_) => const FakeReply(200, {}))
        ..on(
          'POST',
          '/rest/v1/rpc/send_message',
          (request) => FakeReply(200, _message('s1', sender: _me, kind: request.json['p_kind'] as String)),
        );
    });
    tearDown(() => dir.delete(recursive: true));

    test('text', () async {
      final sent = await repo.send('c1', clientId: 'cl1', text: ' Бетон привезли ');

      expect(sent.value.id, 's1');
      expect(supabase.rpcCalls('send_message').single, {
        'p_chat_id': 'c1',
        'p_client_id': 'cl1',
        'p_kind': 'text',
        'p_text': 'Бетон привезли',
      });
    });

    test('a photo: upload with progress, then the message refers to it', () async {
      final file = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      final progress = <double>[];

      final attachment = (await repo.uploadPhoto(
        CompressedPhoto(path: file.path, width: 1600, height: 1200, bytes: 3),
        onProgress: progress.add,
      ))
          .value;
      await repo.send('c1', clientId: 'cl2', attachmentIds: [attachment.id]);

      expect(attachment.url, 'storage:photos/c/u1/a1.jpg');
      expect(attachment.width, 1600);
      expect(progress.last, 1);
      expect(supabase.rpcCalls('send_message').single, {
        'p_chat_id': 'c1',
        'p_client_id': 'cl2',
        'p_kind': 'photo',
        'p_attachment_ids': ['a1'],
      });
    });

    test('a voice note: its length and waveform go with the upload', () async {
      final file = File('${dir.path}/v.m4a')..writeAsBytesSync(List.filled(100, 1));
      final note = VoiceNote(
        path: file.path,
        duration: const Duration(milliseconds: 4200),
        waveform: List.filled(40, 50),
      );

      final attachment = (await repo.uploadVoice(note)).value;
      await repo.send('c1', clientId: 'cl3', attachmentIds: [attachment.id]);

      expect(supabase.rpcCalls('create_upload').single, {
        'p_content_type': 'audio/mp4',
        'p_bytes': 100,
        'p_duration_ms': 4200,
        'p_waveform': List.filled(40, 50),
      });
      expect(attachment.durationMs, 4200);
      expect(supabase.rpcCalls('send_message').single['p_kind'], 'voice');
    });

    test('limits and refusals keep their meaning', () async {
      supabase.rpcFails('send_message', 429, 'too_many_requests');
      expect(
        (await repo.send('c1', clientId: 'x', text: 'a')).failure.code,
        FailureCode.tooManyRequests,
      );
      supabase.rpcFails('send_message', 403, 'attachment_forbidden');
      expect(
        (await repo.send('c1', clientId: 'x', text: 'a')).failure.code,
        FailureCode.forbidden,
      );
    });
  });

  test('read and listened marks', () async {
    supabase
      ..rpc('mark_read', null)
      ..rpc('mark_listened', null);

    await repo.markRead('c1', upTo: 'm2');
    await repo.markListened('c1', messageId: 'v1');

    expect(supabase.rpcCalls('mark_read').single, {'p_chat_id': 'c1', 'p_up_to': 'm2'});
    expect(supabase.rpcCalls('mark_listened').single, {'p_chat_id': 'c1', 'p_message_id': 'v1'});
  });

  test('dispose leaves the channel', () async {
    supabase.rpc('get_chats', <Object>[]);
    final sub = repo.watchChats().listen((_) {});
    await pumpEventQueue();
    await sub.cancel();

    await repo.dispose();

    expect(events.disposed, isTrue);
  });
}
