import 'dart:async';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = User(
  id: 'user-foreman-1',
  email: 'foreman1@buildflow.kg',
  name: 'Бакыт Касымов',
  role: UserRole.foreman,
  companyId: 'company-1',
);

Message _message(String id, {String sender = 'user-owner-1'}) => Message(
      id: id,
      clientId: id,
      chatId: 'chat-1',
      senderId: sender,
      kind: MessageKind.text,
      text: id,
      createdAt: DateTime(2026, 10, 28, 9, int.parse(id.split('-').last)),
    );

/// A repository whose message stream and send results the test controls.
class _ScriptedChatRepository implements ChatRepository {
  final messages = StreamController<List<Message>>();

  /// Each send waits for the next completer the test completes.
  final sends = <(String clientId, Completer<Result<Message>>)>[];
  final marked = <String>[];

  @override
  Stream<List<Message>> watchMessages(String chatId) => messages.stream;

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String text,
    required String clientId,
  }) {
    final completer = Completer<Result<Message>>();
    sends.add((clientId, completer));
    return completer.future;
  }

  @override
  Future<Result<void>> markRead(String chatId, {required String upTo}) async {
    marked.add(upTo);
    return const Success(null);
  }

  @override
  Stream<List<Chat>> watchChats() => const Stream.empty();

  @override
  Future<Result<List<Message>>> loadOlder(
    String chatId, {
    required String before,
  }) async =>
      const Success([]);

  @override
  Future<Result<Chat>> getOrCreateDirect(String userId) =>
      throw UnimplementedError();
}

void main() {
  late _ScriptedChatRepository repo;
  late ProviderContainer container;

  final provider = chatThreadProvider('chat-1');
  ChatThreadNotifier notifier() => container.read(provider.notifier);
  List<Message> messages() => container.read(provider).requireValue.messages;

  Message serverCopy(Message pending, String id) => pending.copyWith(
        id: id,
        status: MessageStatus.sent,
      );

  setUp(() async {
    repo = _ScriptedChatRepository();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        chatRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.listen(provider, (_, __) {});
    repo.messages.add([_message('m-1')]);
    await container.read(provider.future);
  });

  test('a sent message shows at once as sending, then as sent', () async {
    final done = notifier().send('  Бетон привезли  ');
    expect(messages().last.text, 'Бетон привезли');
    expect(messages().last.status, MessageStatus.sending);

    final (clientId, reply) = repo.sends.single;
    final pending = messages().last;
    expect(pending.clientId, clientId);
    reply.complete(Success(serverCopy(pending, 'm-2')));
    expect((await done).isSuccess, isTrue);
    expect(messages().last.status, MessageStatus.sent);

    // The same message arriving on the stream doesn't duplicate it.
    repo.messages.add([_message('m-1'), serverCopy(pending, 'm-2')]);
    await Future<void>.delayed(Duration.zero);
    expect(messages().map((m) => m.id), ['m-1', 'm-2']);
  });

  test('a failed message is marked and retried with the same clientId',
      () async {
    final first = notifier().send('Нужен щебень');
    final (clientId, reply) = repo.sends.single;
    reply.complete(
      const Err(Failure(FailureCode.network, message: 'offline')),
    );
    expect((await first).failure.code, FailureCode.network);
    expect(messages().last.status, MessageStatus.failed);

    final retry = notifier().retry(clientId);
    expect(messages().last.status, MessageStatus.sending);
    expect(repo.sends, hasLength(2));
    final (retryClientId, retryReply) = repo.sends.last;
    expect(retryClientId, clientId);

    retryReply.complete(Success(serverCopy(messages().last, 'm-2')));
    expect((await retry).isSuccess, isTrue);
    expect(messages(), hasLength(2));
    expect(messages().last.status, MessageStatus.sent);
  });

  test('a failed message can be discarded', () async {
    final done = notifier().send('Ошибка');
    repo.sends.single.$2.complete(
      const Err(Failure(FailureCode.network, message: 'offline')),
    );
    await done;
    notifier().discard(messages().last.clientId);
    expect(messages().map((m) => m.id), ['m-1']);
  });

  test('a blank message is not sent', () async {
    final result = await notifier().send('   ');
    expect(result.failure.code, FailureCode.validation);
    expect(repo.sends, isEmpty);
    expect(messages(), hasLength(1));
  });

  test('marks read the latest message from someone else, once', () async {
    await notifier().markRead();
    await notifier().markRead();
    expect(repo.marked, ['m-1']);

    repo.messages.add([_message('m-1'), _message('m-2')]);
    await Future<void>.delayed(Duration.zero);
    await notifier().markRead();
    expect(repo.marked, ['m-1', 'm-2']);

    // Own messages don't need it: sending reads the chat.
    repo.messages.add([
      _message('m-1'),
      _message('m-2'),
      _message('m-3', sender: _me.id),
    ]);
    await Future<void>.delayed(Duration.zero);
    await notifier().markRead();
    expect(repo.marked, ['m-1', 'm-2']);
  });

  test('a message sliding out of the live page stays in the thread',
      () async {
    repo.messages.add([_message('m-2')]);
    await Future<void>.delayed(Duration.zero);
    expect(messages().map((m) => m.id), ['m-1', 'm-2']);
  });
}
