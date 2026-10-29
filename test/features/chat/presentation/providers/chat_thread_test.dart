import 'dart:async';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_photo_compressor.dart';

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
  final sentAttachments = <List<String>>[];
  final marked = <String>[];

  /// Paths of the copies uploaded, in order.
  final uploads = <String>[];

  /// Copies whose next upload fails.
  final failUploads = <String>{};

  @override
  Stream<List<Message>> watchMessages(String chatId) => messages.stream;

  @override
  Future<Result<MessageAttachment>> uploadPhoto(
    CompressedPhoto photo, {
    ValueChanged<double>? onProgress,
  }) async {
    uploads.add(photo.path);
    onProgress?.call(0.5);
    await Future<void>.delayed(Duration.zero);
    if (failUploads.remove(photo.path)) {
      return const Err(Failure(FailureCode.network, message: 'offline'));
    }
    onProgress?.call(1);
    return Success(
      MessageAttachment(
        id: 'att-${photo.path}',
        url: photo.path,
        width: photo.width,
        height: photo.height,
      ),
    );
  }

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  }) {
    final completer = Completer<Result<Message>>();
    sends.add((clientId, completer));
    sentAttachments.add(attachmentIds);
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
  late FakePhotoCompressor compressor;
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
    compressor = FakePhotoCompressor();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        chatRepositoryProvider.overrideWithValue(repo),
        photoCompressorProvider.overrideWithValue(compressor),
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

  group('photos', () {
    const drafts = 'chat:chat-1';
    String copy(String path) => FakePhotoCompressor.copyOf(path);
    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));

    /// Picks [paths] in the message field and sends them.
    Future<Result<Message>> sendPhotos(
      List<String> paths, {
      String caption = '',
    }) {
      container.listen(photoDraftsProvider(drafts), (_, __) {});
      final field = container.read(photoDraftsProvider(drafts).notifier)
        ..add(paths);
      return notifier().sendPhotos(field.takeAll(), caption: caption);
    }

    test('show at once, then compress, upload one by one and send', () async {
      final done = sendPhotos(['/c/1.jpg', '/c/2.jpg'], caption: ' Плита ');
      final pending = messages().last;
      expect(pending.kind, MessageKind.photo);
      expect(pending.text, 'Плита');
      expect(pending.status, MessageStatus.sending);
      // The originals stand in until the copies are uploaded.
      expect(pending.attachments.map((a) => a.url), ['/c/1.jpg', '/c/2.jpg']);

      await settle();
      expect(repo.uploads, [copy('/c/1.jpg'), copy('/c/2.jpg')]);
      expect(repo.sentAttachments.single, [
        'att-${copy('/c/1.jpg')}',
        'att-${copy('/c/2.jpg')}',
      ]);
      final thread = container.read(provider).requireValue;
      expect(thread.uploadProgress.values, [1, 1]);
      expect(thread.messages.last.attachments.first.width, 1600);

      final (clientId, reply) = repo.sends.single;
      expect(clientId, pending.clientId);
      reply.complete(Success(serverCopy(messages().last, 'm-2')));
      expect((await done).isSuccess, isTrue);
      expect(messages().last.status, MessageStatus.sent);
      expect(container.read(provider).requireValue.uploadProgress, isEmpty);
      // The originals go; the copies are the sent photos now.
      expect(compressor.deleted, ['/c/1.jpg', '/c/2.jpg']);
    });

    test('a failed upload fails the message; a retry uploads only the rest',
        () async {
      repo.failUploads.add(copy('/c/2.jpg'));
      final first = sendPhotos(['/c/1.jpg', '/c/2.jpg', '/c/3.jpg']);
      expect((await first).failure.code, FailureCode.network);
      expect(messages().last.status, MessageStatus.failed);
      expect(repo.uploads, [copy('/c/1.jpg'), copy('/c/2.jpg')]);
      expect(repo.sends, isEmpty);

      final retry = notifier().retry(messages().last.clientId);
      expect(messages().last.status, MessageStatus.sending);
      await settle();
      expect(repo.uploads, [
        copy('/c/1.jpg'),
        copy('/c/2.jpg'),
        copy('/c/2.jpg'),
        copy('/c/3.jpg'),
      ]);
      expect(repo.sentAttachments.single, hasLength(3));
      repo.sends.single.$2.complete(
        Success(serverCopy(messages().last, 'm-2')),
      );
      expect((await retry).isSuccess, isTrue);
    });

    test('a failed send is retried with the same clientId, no new uploads',
        () async {
      final first = sendPhotos(['/c/1.jpg']);
      await settle();
      repo.sends.single.$2.complete(
        const Err(Failure(FailureCode.network, message: 'offline')),
      );
      expect((await first).isFailure, isTrue);

      final retry = notifier().retry(messages().last.clientId);
      await settle();
      expect(repo.uploads, [copy('/c/1.jpg')]);
      expect(repo.sends, hasLength(2));
      expect(repo.sends.last.$1, repo.sends.first.$1);
      expect(repo.sentAttachments.last, ['att-${copy('/c/1.jpg')}']);
      repo.sends.last.$2.complete(Success(serverCopy(messages().last, 'm-2')));
      expect((await retry).isSuccess, isTrue);
    });

    test('a photo that fails to compress fails the message, not loses it',
        () async {
      compressor.failing.add('/c/2.jpg');
      final first = sendPhotos(['/c/1.jpg', '/c/2.jpg']);
      expect((await first).failure.code, FailureCode.photoProcessing);
      expect(messages().last.status, MessageStatus.failed);
      expect(messages().last.attachments.last.url, '/c/2.jpg');
      expect(compressor.deleted, isEmpty);

      compressor.failing.clear();
      final retry = notifier().retry(messages().last.clientId);
      await settle();
      // Compressed again from the original; the first photo is not redone.
      expect(compressor.compressed, ['/c/1.jpg', '/c/2.jpg', '/c/2.jpg']);
      expect(repo.uploads, [copy('/c/1.jpg'), copy('/c/2.jpg')]);
      repo.sends.single.$2.complete(
        Success(serverCopy(messages().last, 'm-2')),
      );
      expect((await retry).isSuccess, isTrue);
    });

    test('discarding a failed photo message deletes its files', () async {
      repo.failUploads.add(copy('/c/1.jpg'));
      await sendPhotos(['/c/1.jpg']);
      notifier().discard(messages().last.clientId);
      expect(messages().map((m) => m.id), ['m-1']);
      expect(compressor.deleted, ['/c/1.jpg', copy('/c/1.jpg')]);
    });

    test('nothing or more than ten photos are not sent', () async {
      expect(
        (await notifier().sendPhotos(const [])).failure.code,
        FailureCode.validation,
      );
      final eleven = await sendPhotos([
        for (var i = 0; i < 11; i++) '/c/$i.jpg',
      ]);
      expect(eleven.failure.code, FailureCode.validation);
      expect(repo.uploads, isEmpty);
    });
  });
}
