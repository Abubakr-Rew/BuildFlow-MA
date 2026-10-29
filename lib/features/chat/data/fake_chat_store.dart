import 'dart:async';
import 'dart:math';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/chat/data/fake_chat_demo_data.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter/foundation.dart';

/// The chat «server» in demo mode: chats and messages of every user in
/// memory, shared by all sessions of the process, so after logging out and
/// in as someone else the messages of the first user are there.
///
/// Follows the access rules of docs/api-contract.md («Чат»):
/// - a project chat's participants are the project team: the company's
///   directors plus the project's foremen and workers ([syncProject]);
/// - direct chats only within one company;
/// - a member removed from the company loses every chat of it, direct
///   ones included ([FakeTeamStore] tells the store);
/// - a photo can be attached only by the user who uploaded it, and once.
///
/// Created only by `fakeChatStoreProvider`; tests may create their own.
class FakeChatStore {
  FakeChatStore({
    required FakeTeamStore teamStore,
    Iterable<Project> projects = const [],
    bool demoHistory = true,
    this.echo = false,
    DateTime Function()? now,
    Random? random,
  })  : _team = teamStore,
        _now = now ?? DateTime.now,
        _random = random ?? Random() {
    for (final project in projects) {
      _createProjectChat(project);
    }
    if (demoHistory) _seedDemo();
    _team.addMembersListener(_onMembersChanged);
  }

  final FakeTeamStore _team;
  final DateTime Function() _now;
  final Random _random;

  /// Echo companion: in a direct chat the other person reads a new message
  /// after 1–2 s and answers with a short line after 2–4 s.
  final bool echo;

  final Map<String, _ChatRecord> _chats = {};

  /// `chatId/senderId/clientId` → index of the message in its chat.
  final Map<String, int> _byClientId = {};

  /// Uploaded photos not attached to a message yet, by attachment id.
  final Map<String, ({String ownerId, MessageAttachment attachment})>
      _uploads = {};
  var _uploadSeq = 0;
  final _changes = StreamController<void>.broadcast();
  final Set<Timer> _timers = {};
  final Set<String> _echoing = {};
  var _seq = 0;
  var _disposed = false;

  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _team.removeMembersListener(_onMembersChanged);
    unawaited(_changes.close());
  }

  // ── Reads ──────────────────────────────────────────────────

  /// Chats of [userId], latest activity first, updated on every change.
  Stream<List<Chat>> watchChats(String userId) =>
      _watch(() => chatsFor(userId));

  /// The last [chatPageSize] messages of the chat, oldest first.
  Stream<List<Message>> watchMessages(String chatId, String userId) =>
      _watch(() => messagesFor(chatId, userId));

  Result<List<Chat>> chatsFor(String userId) {
    final member = _team.memberByUserId(userId);
    if (member == null) return Err(_notInCompany(userId));
    final chats = [
      for (final chat in _chats.values)
        if (chat.companyId == member.companyId &&
            chat.participants.contains(userId))
          _chatView(chat, userId),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Success(chats);
  }

  Result<List<Message>> messagesFor(String chatId, String userId) {
    final chat = _chats[chatId];
    final denied = _denied(chat, chatId, userId);
    if (denied != null) return Err(denied);
    final from = max(0, chat!.messages.length - chatPageSize);
    return Success([
      for (var i = from; i < chat.messages.length; i++)
        _messageView(chat, i, userId),
    ]);
  }

  Result<List<Message>> loadOlder(
    String chatId,
    String userId, {
    required String before,
  }) {
    final chat = _chats[chatId];
    final denied = _denied(chat, chatId, userId);
    if (denied != null) return Err(denied);
    final index = chat!.messages.indexWhere((m) => m.id == before);
    if (index == -1) {
      return Err(
        Failure(FailureCode.notFound, message: 'Message $before not found'),
      );
    }
    final from = max(0, index - chatPageSize);
    return Success([
      for (var i = from; i < index; i++) _messageView(chat, i, userId),
    ]);
  }

  // ── Writes ─────────────────────────────────────────────────

  /// A photo uploaded by [userId], to attach to one of their messages. In
  /// demo mode [url] is the compressed copy on the phone.
  Result<MessageAttachment> registerUpload(
    String userId, {
    required String url,
    required int width,
    required int height,
  }) {
    if (_team.memberByUserId(userId) == null) return Err(_notInCompany(userId));
    final attachment = MessageAttachment(
      id: 'att-${++_uploadSeq}',
      url: url,
      width: width,
      height: height,
    );
    _uploads[attachment.id] = (ownerId: userId, attachment: attachment);
    return Success(attachment);
  }

  Result<Message> send(
    String chatId,
    String userId, {
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  }) {
    final chat = _chats[chatId];
    final denied = _denied(chat, chatId, userId);
    if (denied != null) return Err(denied);

    final key = '$chatId/$userId/$clientId';
    final existing = _byClientId[key];
    if (existing != null) return Success(_messageView(chat!, existing, userId));

    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachmentIds.isEmpty) ||
        trimmed.length > maxMessageLength ||
        attachmentIds.length > maxPhotosPerMessage) {
      return const Err(
        Failure(
          FailureCode.validation,
          message: 'Text must be 1–$maxMessageLength characters, '
              'or up to $maxPhotosPerMessage photos',
        ),
      );
    }
    final attachments = <MessageAttachment>[];
    for (final id in attachmentIds) {
      final upload = _uploads[id];
      if (upload == null || upload.ownerId != userId) {
        return Err(
          Failure(
            FailureCode.forbidden,
            message: 'Attachment $id was not uploaded by $userId',
          ),
        );
      }
      attachments.add(upload.attachment);
    }
    if (chat!.type.isDirect) {
      final peer = chat.participants.firstWhere((id) => id != userId);
      if (!_inCompany(peer, chat.companyId)) {
        return Err(
          Failure(
            FailureCode.forbidden,
            message: 'User $peer is no longer in the company',
          ),
        );
      }
    }

    attachmentIds.forEach(_uploads.remove);
    final index = _append(
      chat,
      userId,
      text: trimmed,
      clientId: clientId,
      attachments: attachments,
    );
    _byClientId[key] = index;
    _emit();
    _scheduleEcho(chat, userId);
    return Success(_messageView(chat, index, userId));
  }

  Result<Chat> getOrCreateDirect(String userId, String peerId) {
    final me = _team.memberByUserId(userId);
    if (me == null) return Err(_notInCompany(userId));
    if (peerId == userId) {
      return const Err(
        Failure(FailureCode.validation, message: 'Cannot chat with oneself'),
      );
    }
    final peer = _team.memberByUserId(peerId);
    if (peer == null || peer.companyId != me.companyId) {
      return Err(
        Failure(FailureCode.notFound, message: 'User $peerId not found'),
      );
    }

    final pair = {userId, peerId};
    var chat = _chats.values
        .where((c) => c.type.isDirect && setEquals(c.participants, pair))
        .firstOrNull;
    if (chat == null) {
      chat = _ChatRecord(
        id: directChatId(userId, peerId),
        type: ChatType.direct,
        companyId: me.companyId,
        participants: pair,
        updatedAt: _now(),
      );
      _chats[chat.id] = chat;
      _emit();
    }
    return Success(_chatView(chat, userId));
  }

  Result<void> markRead(String chatId, String userId, {required String upTo}) {
    final chat = _chats[chatId];
    final denied = _denied(chat, chatId, userId);
    if (denied != null) return Err(denied);
    final index = chat!.messages.indexWhere((m) => m.id == upTo);
    if (index == -1) {
      return Err(
        Failure(FailureCode.notFound, message: 'Message $upTo not found'),
      );
    }
    if (_readUpTo(chat, userId, index)) _emit();
    return const Success(null);
  }

  /// Brings the project chat in line with [project]: its name and team.
  /// Members who joined or left get a system message.
  void syncProject(Project project) {
    final chat = _chats['chat-${project.id}'];
    if (chat == null) {
      _createProjectChat(project);
    } else {
      chat.title = project.name;
      _setParticipants(chat, _teamOf(project));
    }
    _emit();
  }

  /// Id of the direct chat of two users, the same in either order.
  static String directChatId(String a, String b) {
    final pair = [a, b]..sort();
    return 'chat-direct-${pair.join('-')}';
  }

  // ── Internals ──────────────────────────────────────────────

  bool _inCompany(String userId, String companyId) =>
      _team.memberByUserId(userId)?.companyId == companyId;

  static Failure _notInCompany(String userId) => Failure(
        FailureCode.forbidden,
        message: 'User $userId is not in a company',
      );

  /// Why [userId] can't use the chat, or `null` if they can.
  Failure? _denied(_ChatRecord? chat, String chatId, String userId) {
    if (chat == null) {
      return Failure(FailureCode.notFound, message: 'Chat $chatId not found');
    }
    if (!chat.participants.contains(userId) ||
        !_inCompany(userId, chat.companyId)) {
      return Failure(
        FailureCode.forbidden,
        message: 'User $userId is not in chat $chatId',
      );
    }
    return null;
  }

  Set<String> _teamOf(Project project) => {
        for (final m in _team.membersOf(project.companyId))
          if (m.role.isOwner) m.userId,
        ...project.foremanIds,
        ...project.workerIds,
      }.where((id) => _inCompany(id, project.companyId)).toSet();

  void _createProjectChat(Project project) {
    final chat = _ChatRecord(
      id: 'chat-${project.id}',
      type: ChatType.project,
      companyId: project.companyId,
      projectId: project.id,
      title: project.name,
      participants: _teamOf(project),
      updatedAt: _now(),
    );
    _chats[chat.id] = chat;
  }

  void _setParticipants(_ChatRecord chat, Set<String> next) {
    final removed = chat.participants.difference(next);
    final added = next.difference(chat.participants);
    chat.participants = {...next};
    for (final id in removed) {
      _appendSystem(chat, ChatSystemEvent.memberRemoved, id);
    }
    for (final id in added) {
      _appendSystem(chat, ChatSystemEvent.memberAdded, id);
    }
  }

  /// A member left the company: they drop out of the project chats. Their
  /// direct chats stay for the other person, read-only.
  void _onMembersChanged() {
    for (final chat in _chats.values.where((c) => c.type.isProject)) {
      _setParticipants(
        chat,
        chat.participants.where((id) => _inCompany(id, chat.companyId)).toSet(),
      );
    }
    _emit();
  }

  /// Appends a message from [senderId], who has thereby read the chat up
  /// to it: text, or photos with [text] as the caption. Returns its index.
  int _append(
    _ChatRecord chat,
    String senderId, {
    required String text,
    String? clientId,
    DateTime? at,
    List<MessageAttachment> attachments = const [],
  }) {
    final id = 'msg-${++_seq}';
    final createdAt = at ?? _now();
    chat.messages.add(
      Message(
        id: id,
        clientId: clientId ?? id,
        chatId: chat.id,
        senderId: senderId,
        kind: attachments.isEmpty ? MessageKind.text : MessageKind.photo,
        text: attachments.isNotEmpty && text.isEmpty ? null : text,
        attachments: attachments,
        createdAt: createdAt,
      ),
    );
    final index = chat.messages.length - 1;
    chat
      ..lastRead[senderId] = index
      ..updatedAt = createdAt;
    return index;
  }

  void _appendSystem(
    _ChatRecord chat,
    ChatSystemEvent event,
    String subjectUserId,
  ) {
    final id = 'msg-${++_seq}';
    final now = _now();
    chat
      ..messages.add(
        Message(
          id: id,
          clientId: id,
          chatId: chat.id,
          senderId: systemSenderId,
          kind: MessageKind.system,
          systemEvent: event,
          subjectUserId: subjectUserId,
          createdAt: now,
        ),
      )
      ..updatedAt = now;
  }

  /// Whether the read mark of [userId] moved forward.
  bool _readUpTo(_ChatRecord chat, String userId, int index) {
    if (index <= (chat.lastRead[userId] ?? -1)) return false;
    chat.lastRead[userId] = index;
    return true;
  }

  Chat _chatView(_ChatRecord chat, String userId) {
    final lastRead = chat.lastRead[userId] ?? -1;
    var unread = 0;
    for (var i = lastRead + 1; i < chat.messages.length; i++) {
      final m = chat.messages[i];
      if (m.senderId != userId && m.kind != MessageKind.system) unread++;
    }
    return Chat(
      id: chat.id,
      type: chat.type,
      participantIds: chat.participants.toList()..sort(),
      updatedAt: chat.updatedAt,
      projectId: chat.projectId,
      title: chat.title,
      lastMessage: chat.messages.isEmpty
          ? null
          : _messageView(chat, chat.messages.length - 1, userId),
      unreadCount: unread,
    );
  }

  /// The message at [index] as [userId] sees it: their own messages are
  /// [MessageStatus.read] once someone else has read them.
  Message _messageView(_ChatRecord chat, int index, String userId) {
    final m = chat.messages[index];
    if (m.senderId != userId || m.kind == MessageKind.system) return m;
    final readByOthers =
        chat.lastRead.entries.any((e) => e.key != userId && e.value >= index);
    return readByOthers ? m.copyWith(status: MessageStatus.read) : m;
  }

  void _emit() {
    if (!_disposed) _changes.add(null);
  }

  /// A stream of [read] now and after every change. Repeats of the same
  /// value or of an error are skipped.
  Stream<T> _watch<T extends List<Object>>(Result<T> Function() read) {
    late final StreamController<T> controller;
    StreamSubscription<void>? changes;
    Result<T>? last;

    void push() {
      final next = read();
      final previous = last;
      last = next;
      switch (next) {
        case Success(:final data):
          if (previous case Success(data: final old) when listEquals(old, data)) {
            return;
          }
          controller.add(data);
        case Err(:final failure):
          if (previous is Err<T>) return;
          controller.addError(failure);
      }
    }

    controller = StreamController<T>(
      onListen: () {
        push();
        changes = _changes.stream.listen((_) => push());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  // ── Echo companion ─────────────────────────────────────────

  void _scheduleEcho(_ChatRecord chat, String senderId) {
    if (!echo || !chat.type.isDirect || _echoing.contains(chat.id)) return;
    final peer = chat.participants.firstWhere((id) => id != senderId);
    _echoing.add(chat.id);
    _later(Duration(milliseconds: 1000 + _random.nextInt(1000)), () {
      if (_readUpTo(chat, peer, chat.messages.length - 1)) _emit();
    });
    _later(Duration(milliseconds: 2000 + _random.nextInt(2000)), () {
      _echoing.remove(chat.id);
      if (!_inCompany(peer, chat.companyId)) return;
      _append(
        chat,
        peer,
        text: demoEchoReplies[_random.nextInt(demoEchoReplies.length)],
      );
      _emit();
    });
  }

  void _later(Duration delay, void Function() action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (!_disposed) action();
    });
    _timers.add(timer);
  }

  // ── Demo history ───────────────────────────────────────────

  void _seedDemo() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
    DateTime dayAt(int daysAgo, int hour, int minute) =>
        today.subtract(Duration(days: daysAgo)).add(
              Duration(hours: hour, minutes: minute),
            );

    void say(_ChatRecord? chat, String sender, String text, DateTime at) {
      if (chat == null) return;
      _append(chat, sender, text: text, at: at);
    }

    // Demo photos are `fake:` placeholders; portrait every third one.
    var demoPhoto = 0;
    void show(
      _ChatRecord? chat,
      String sender,
      int count,
      DateTime at, {
      String caption = '',
    }) {
      if (chat == null) return;
      final attachments = [
        for (var i = 0; i < count; i++)
          MessageAttachment(
            id: 'att-demo-${++demoPhoto}',
            url: 'fake:chat-$demoPhoto',
            width: demoPhoto % 3 == 0 ? 1200 : 1600,
            height: demoPhoto % 3 == 0 ? 1600 : 1200,
          ),
      ];
      _append(chat, sender, text: caption, at: at, attachments: attachments);
    }

    // Everyone has read everything, except the last [unread] messages from
    // others for [userId].
    void readAll(_ChatRecord? chat, {Map<String, int> unread = const {}}) {
      if (chat == null) return;
      for (final userId in chat.participants) {
        var left = unread[userId] ?? 0;
        var index = chat.messages.length - 1;
        while (left > 0 && index >= 0) {
          if (chat.messages[index].senderId != userId) left--;
          index--;
        }
        chat.lastRead[userId] = index;
      }
    }

    final alaToo = _chats['chat-project-1'];
    for (var day = 4; day >= 1; day--) {
      for (var i = 0; i < 15; i++) {
        final (sender, text) =
            demoAlaTooHistory[(day * 5 + i) % demoAlaTooHistory.length];
        say(alaToo, sender, text, dayAt(day, 8, 5 + i * 17));
      }
    }
    say(alaToo, demoForeman1Id,
        'Доброе утро. Бетон на 8-й этаж заказал на 9:00.', ago(130));
    say(alaToo, demoWorker1Id, 'Миксер приехал, начинаем заливку.', ago(118));
    show(alaToo, demoWorker1Id, 1, ago(117));
    say(alaToo, demoWorker1Id, 'Второй вибратор взяли из бытовки.', ago(116));
    show(alaToo, demoForeman1Id, 3, ago(62),
        caption: 'Армирование плиты перед заливкой');
    say(alaToo, demoForeman1Id,
        'Залили 12 кубов из 20, перерыв на обед.', ago(60));
    say(alaToo, demoOwnerId,
        'Принято. Фото после заливки добавьте в отчёт.', ago(45));
    say(alaToo, demoForeman1Id, 'Хорошо, к 17:00 будет отчёт.', ago(20));
    readAll(alaToo, unread: {demoWorker1Id: 2});

    final gorny = _chats['chat-project-2'];
    say(gorny, demoForeman2Id,
        'По коттеджу №4 залили фундамент.', dayAt(1, 16, 40));
    say(gorny, demoWorker2Id,
        'Нужна ещё одна бетономешалка, одна не справляется.', dayAt(1, 16, 52));
    say(gorny, demoOwnerId, 'Арендуем, завтра будет.', dayAt(1, 17, 5));
    show(gorny, demoForeman2Id, 6, dayAt(1, 17, 40),
        caption: 'Итоги дня: фундамент №4 и кладка №5');
    say(gorny, demoForeman2Id, 'Бетономешалку привезли, спасибо.', ago(90));
    say(gorny, demoForeman1Id,
        'Кровельщики выходят на №2 в понедельник.', ago(40));
    say(gorny, demoWorker2Id,
        'Дорогу к участку размыло, грузовик не проходит. Нужен щебень.',
        ago(15));
    readAll(gorny, unread: {demoOwnerId: 2, demoForeman1Id: 1});

    final baitik = _chats['chat-project-3'];
    say(baitik, demoOwnerId,
        'Ставим объект на паузу до согласования проекта с арендатором.',
        dayAt(3, 10, 15));
    say(baitik, demoForeman2Id,
        'Понял. Технику вывожу в «Горный».', dayAt(3, 10, 32));
    say(baitik, demoWorker3Id, 'А нам куда выходить?', dayAt(3, 11, 2));
    say(baitik, demoForeman2Id,
        'Азамат, с понедельника в «Горный», Нурлан покажет.', dayAt(3, 11, 10));
    show(baitik, demoWorker3Id, 2, dayAt(3, 11, 40), caption: 'Леса вывезли');
    readAll(baitik);

    final warehouse = _chats['chat-project-4'];
    say(warehouse, demoOwnerId,
        'Объект сдан, акт подписан. Всем спасибо!', dayAt(14, 15, 0));
    readAll(warehouse);

    final ownerForeman = _directForSeed(demoOwnerId, demoForeman1Id);
    say(ownerForeman, demoOwnerId,
        'Бакыт, завтра в 10 приедет заказчик на «Ала-Тоо», встретишь?',
        dayAt(1, 18, 10));
    say(ownerForeman, demoForeman1Id,
        'Да, встречу. Подготовлю журнал работ.', dayAt(1, 18, 25));
    show(ownerForeman, demoForeman1Id, 1, ago(12));
    say(ownerForeman, demoForeman1Id,
        'Заказчик доволен, просит ускорить фасад.', ago(10));
    readAll(ownerForeman, unread: {demoOwnerId: 1});

    final foremanWorker = _directForSeed(demoForeman1Id, demoWorker1Id);
    say(foremanWorker, demoForeman1Id,
        'Эрлан, возьми с собой нивелир.', ago(180));
    say(foremanWorker, demoWorker1Id, 'Взял.', ago(175));
    readAll(foremanWorker);
  }

  _ChatRecord? _directForSeed(String a, String b) => switch (
        getOrCreateDirect(a, b)
      ) {
        Success(:final data) => _chats[data.id],
        Err() => null,
      };
}

class _ChatRecord {
  _ChatRecord({
    required this.id,
    required this.type,
    required this.companyId,
    required this.participants,
    required this.updatedAt,
    this.projectId,
    this.title = '',
  });

  final String id;
  final ChatType type;
  final String companyId;
  final String? projectId;
  String title;
  Set<String> participants;
  DateTime updatedAt;

  /// Oldest first; indexes never change.
  final List<Message> messages = [];

  /// userId → index in [messages] of the last message they have read.
  final Map<String, int> lastRead = {};
}
