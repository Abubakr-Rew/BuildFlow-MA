import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _owner = 'user-owner-1';
const _foreman1 = 'user-foreman-1';
const _foreman2 = 'user-foreman-2';
const _worker1 = 'user-worker-1';
const _worker2 = 'user-worker-2';
const _alaToo = 'chat-project-1';
const _gorny = 'chat-project-2';

/// Lets the store's broadcast events reach the listeners.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTeamStore team;
  late FakeChatStore store;

  FakeChatStore createStore({bool demoHistory = false, bool echo = false}) =>
      FakeChatStore(
        teamStore: team,
        projects: FakeProjectRepository.seed,
        demoHistory: demoHistory,
        echo: echo,
      );

  setUp(() {
    team = FakeTeamStore();
    store = createStore();
  });

  tearDown(() => store.dispose());

  Message send(String chatId, String userId, String text, {String? clientId}) =>
      store
          .send(chatId, userId, text: text, clientId: clientId ?? text)
          .value;

  Chat chatOf(String userId, String chatId) =>
      store.chatsFor(userId).value.firstWhere((c) => c.id == chatId);

  /// Events of a stream, collected while the test runs.
  List<T> collect<T>(Stream<T> stream, {List<Object>? errors}) {
    final events = <T>[];
    final sub = stream.listen(events.add, onError: errors?.add);
    addTearDown(sub.cancel);
    return events;
  }

  group('project chats', () {
    test('the team of a project is its directors, foremen and workers', () {
      expect(
        chatOf(_owner, _gorny).participantIds,
        unorderedEquals([_owner, _foreman1, _foreman2, _worker1, _worker2]),
      );
      expect(chatOf(_owner, _gorny).title, 'Коттеджный посёлок «Горный»');
    });

    test('a foreman sees only the chats of their projects', () {
      final ids = store.chatsFor(_foreman1).value.map((c) => c.id);
      expect(ids, unorderedEquals([_alaToo, _gorny]));
    });
  });

  group('send', () {
    test('a message shows up in the stream of another participant', () async {
      final chats = collect(store.watchChats(_owner));
      await _flush();
      expect(chats.single.firstWhere((c) => c.id == _alaToo).unreadCount, 0);

      send(_alaToo, _foreman1, 'Бетон залили');
      await _flush();

      final chat = chats.last.firstWhere((c) => c.id == _alaToo);
      expect(chat.lastMessage?.text, 'Бетон залили');
      expect(chat.lastMessage?.senderId, _foreman1);
      expect(chat.unreadCount, 1);
      // The latest activity goes first.
      expect(chats.last.first.id, _alaToo);
    });

    test('the message stream of the chat gets the new message', () async {
      final messages = collect(store.watchMessages(_alaToo, _worker1));
      await _flush();
      send(_alaToo, _foreman1, 'Привет');
      await _flush();
      expect(messages.last.single.text, 'Привет');
    });

    test('is idempotent by clientId', () {
      final first = send(_alaToo, _foreman1, 'Один раз', clientId: 'c-1');
      final again = send(_alaToo, _foreman1, 'Один раз', clientId: 'c-1');
      expect(again.id, first.id);
      expect(store.messagesFor(_alaToo, _owner).value, hasLength(1));
    });

    test('the same clientId from another sender is a new message', () {
      send(_alaToo, _foreman1, 'Да', clientId: 'c-1');
      send(_alaToo, _owner, 'Да', clientId: 'c-1');
      expect(store.messagesFor(_alaToo, _owner).value, hasLength(2));
    });

    test('rejects a blank or too long text', () {
      for (final text in ['   ', 'я' * (maxMessageLength + 1)]) {
        final result =
            store.send(_alaToo, _foreman1, text: text, clientId: text);
        expect(result.failure.code, FailureCode.validation);
      }
    });

    test('is forbidden outside the chat', () {
      final result =
          store.send(_alaToo, _worker2, text: 'Привет', clientId: 'c');
      expect(result.failure.code, FailureCode.forbidden);
    });

    test('of an unknown chat is not found', () {
      final result =
          store.send('chat-x', _owner, text: 'Привет', clientId: 'c');
      expect(result.failure.code, FailureCode.notFound);
    });
  });

  group('unread and markRead', () {
    test('counts messages of others since the last read one', () {
      send(_alaToo, _foreman1, 'Раз');
      final two = send(_alaToo, _worker1, 'Два');
      expect(chatOf(_owner, _alaToo).unreadCount, 2);
      expect(chatOf(_foreman1, _alaToo).unreadCount, 1);
      // Sending reads the chat up to the own message.
      expect(chatOf(_worker1, _alaToo).unreadCount, 0);

      expect(store.markRead(_alaToo, _owner, upTo: two.id).isSuccess, isTrue);
      expect(chatOf(_owner, _alaToo).unreadCount, 0);
    });

    test('an own message is read once someone else has read it', () {
      final mine = send(_alaToo, _foreman1, 'Фото скинул');
      expect(mine.status, MessageStatus.sent);

      store.markRead(_alaToo, _owner, upTo: mine.id);
      final seen = store.messagesFor(_alaToo, _foreman1).value.single;
      expect(seen.status, MessageStatus.read);
    });

    test('an unknown message is not found', () {
      final result = store.markRead(_alaToo, _owner, upTo: 'msg-x');
      expect(result.failure.code, FailureCode.notFound);
    });
  });

  group('getOrCreateDirect', () {
    test('creates the chat once', () {
      final first = store.getOrCreateDirect(_owner, _worker2).value;
      final again = store.getOrCreateDirect(_owner, _worker2).value;
      final fromPeer = store.getOrCreateDirect(_worker2, _owner).value;
      expect(again.id, first.id);
      expect(fromPeer.id, first.id);
      expect(first.type, ChatType.direct);
      expect(first.participantIds, unorderedEquals([_owner, _worker2]));
      expect(
        store.chatsFor(_owner).value.where((c) => c.type.isDirect),
        hasLength(1),
      );
    });

    test('never with oneself', () {
      final result = store.getOrCreateDirect(_owner, _owner);
      expect(result.failure.code, FailureCode.validation);
    });

    test('only within the company', () {
      final result = store.getOrCreateDirect(_owner, 'user-stranger');
      expect(result.failure.code, FailureCode.notFound);
    });
  });

  group('team changes', () {
    final alaTooProject = FakeProjectRepository.seed.first;

    test('a member removed from the project loses the chat', () async {
      final chats = collect(store.watchChats(_worker1));
      final errors = <Object>[];
      final messages =
          collect(store.watchMessages(_alaToo, _worker1), errors: errors);
      await _flush();
      expect(chats.last.map((c) => c.id), contains(_alaToo));

      store.syncProject(alaTooProject.copyWith(workerIds: []));
      await _flush();

      expect(chats.last.map((c) => c.id), isNot(contains(_alaToo)));
      expect((errors.single as Failure).code, FailureCode.forbidden);

      // New messages don't reach them.
      final before = messages.length;
      send(_alaToo, _foreman1, 'Без Эрлана');
      await _flush();
      expect(messages, hasLength(before));
      expect(
        store.messagesFor(_alaToo, _worker1).failure.code,
        FailureCode.forbidden,
      );
      expect(
        store.send(_alaToo, _worker1, text: 'А я?', clientId: 'c').failure.code,
        FailureCode.forbidden,
      );
    });

    test('joining and leaving shows up as system messages', () {
      store.syncProject(
        alaTooProject.copyWith(workerIds: [_worker2], foremanIds: [_foreman1]),
      );
      final events = store
          .messagesFor(_alaToo, _owner)
          .value
          .map((m) => (m.kind, m.systemEvent, m.subjectUserId));
      expect(
        events,
        unorderedEquals([
          (MessageKind.system, ChatSystemEvent.memberRemoved, _worker1),
          (MessageKind.system, ChatSystemEvent.memberAdded, _worker2),
        ]),
      );
      // System messages don't count as unread.
      expect(chatOf(_owner, _alaToo).unreadCount, 0);
      expect(chatOf(_worker2, _alaToo).participantIds, contains(_worker2));
    });

    test('a member removed from the company loses every chat, direct too',
        () async {
      final direct = store.getOrCreateDirect(_owner, _worker1).value;
      send(direct.id, _owner, 'Эрлан, зайди');
      final errors = <Object>[];
      collect(store.watchChats(_worker1), errors: errors);
      await _flush();

      expect(team.removeMember('member-4'), isTrue);
      await _flush();

      expect((errors.single as Failure).code, FailureCode.forbidden);
      expect(store.chatsFor(_worker1).failure.code, FailureCode.forbidden);
      expect(
        store.messagesFor(direct.id, _worker1).failure.code,
        FailureCode.forbidden,
      );
      // Gone from the project chats as well.
      expect(chatOf(_owner, _alaToo).participantIds, isNot(contains(_worker1)));
      // The director keeps the history but can't write to them any more.
      expect(store.messagesFor(direct.id, _owner).value, isNotEmpty);
      expect(
        store
            .send(direct.id, _owner, text: 'Ты где?', clientId: 'c')
            .failure
            .code,
        FailureCode.forbidden,
      );
    });
  });

  group('demo history', () {
    setUp(() {
      store.dispose();
      store = createStore(demoHistory: true);
    });

    test('the director starts with unread messages', () {
      final unread = store
          .chatsFor(_owner)
          .value
          .fold<int>(0, (sum, c) => sum + c.unreadCount);
      expect(unread, greaterThan(0));
    });

    test('pages through older messages', () {
      final page = store.messagesFor(_alaToo, _owner).value;
      expect(page, hasLength(chatPageSize));

      final older =
          store.loadOlder(_alaToo, _owner, before: page.first.id).value;
      expect(older, isNotEmpty);
      expect(older.length, lessThan(chatPageSize));
      expect(older.last.createdAt.isBefore(page.first.createdAt), isTrue);
    });
  });

  testWidgets('the echo companion reads and answers in a direct chat',
      (tester) async {
    store.dispose();
    store = createStore(echo: true);
    final chat = store.getOrCreateDirect(_owner, _foreman1).value;
    final mine = send(chat.id, _owner, 'Как дела на объекте?');

    await tester.pump(const Duration(milliseconds: 2100));
    expect(
      store.messagesFor(chat.id, _owner).value.first.status,
      MessageStatus.read,
    );

    await tester.pump(const Duration(seconds: 2));
    final messages = store.messagesFor(chat.id, _owner).value;
    expect(messages, hasLength(2));
    expect(messages.first.id, mine.id);
    expect(messages.last.senderId, _foreman1);
    expect(chatOf(_owner, chat.id).unreadCount, 1);

    // Project chats stay quiet.
    send(_alaToo, _owner, 'Всем привет');
    await tester.pump(const Duration(seconds: 5));
    expect(store.messagesFor(_alaToo, _owner).value, hasLength(1));
  });
}
