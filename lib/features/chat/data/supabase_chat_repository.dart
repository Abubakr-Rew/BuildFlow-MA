import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/supabase/json.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/chat/data/chat_events.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:flutter/foundation.dart';

/// [ChatRepository] of the signed-in user over the chat RPCs and their
/// Realtime channel ([ChatEvents]).
///
/// The lists of [watchChats] and [watchMessages] are loaded once, then kept
/// up to date by the events. Events missed while the channel was down are
/// caught up when it rejoins and when the app comes back
/// ([onAppResumed]): the chats again and, for every open chat, the
/// messages after the last one known (`get_messages(after:)`).
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository({
    required this.gateway,
    required this.uploads,
    required this.userId,
    required this.events,
  });

  final SupabaseGateway gateway;
  final SupabaseUploads uploads;

  /// The signed-in user; `null` without a session.
  final String? userId;

  /// The user's realtime channel; owned (and left) by this repository.
  final ChatEvents? events;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _started = false;

  List<Chat>? _chats;
  Future<void>? _loadingChats;
  final _chatsChanged = StreamController<List<Chat>>.broadcast();
  final Map<String, _Feed> _feeds = {};

  /// Attachments this user uploaded as voice notes: `send` says the kind.
  final Set<String> _voiceUploads = {};

  Future<void>? _catchingUp;
  bool _catchUpAgain = false;

  static const _noSession =
      Failure(FailureCode.sessionExpired, message: 'Not signed in');

  void _start() {
    final events = this.events;
    if (_started || events == null) return;
    _started = true;
    _subscriptions
      ..add(events.events.listen(_onEvent))
      ..add(events.rejoined.listen((_) => unawaited(catchUp())));
    events.connect();
  }

  // ── Chats ──────────────────────────────────────────────────

  @override
  Stream<List<Chat>> watchChats() {
    if (userId == null) return Stream.error(_noSession);
    return Stream.multi((listener) {
      _start();
      final changes = _chatsChanged.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      if (_chats case final chats?) {
        listener.add(chats);
      } else {
        unawaited(_loadChats());
      }
      listener.onCancel = changes.cancel;
    });
  }

  Future<void> _loadChats() => _loadingChats ??= () async {
        final result = await gateway.rpc('get_chats', listOf(Chat.fromJson));
        _loadingChats = null;
        switch (result) {
          case Success(:final value):
            _setChats(value);
          case Err(:final failure):
            if (_chats == null) _chatsChanged.addError(failure);
        }
      }();

  void _setChats(List<Chat> chats) {
    _chats = [...chats]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!_chatsChanged.isClosed) _chatsChanged.add(_chats!);
  }

  void _upsertChat(Chat chat) {
    final chats = _chats;
    if (chats == null) return;
    _setChats([
      for (final c in chats)
        if (c.id != chat.id) c,
      chat,
    ]);
  }

  // ── Messages ───────────────────────────────────────────────

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    if (userId == null) return Stream.error(_noSession);
    return Stream.multi((listener) {
      _start();
      final feed = _feeds.putIfAbsent(chatId, () => _Feed(chatId));
      feed.listeners++;
      final changes = feed.changes.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      if (feed.loaded) {
        listener.add(feed.latest);
      } else {
        unawaited(_loadLatest(feed));
      }
      listener.onCancel = () async {
        await changes.cancel();
        if (--feed.listeners == 0) {
          _feeds.remove(chatId);
          await feed.changes.close();
        }
      };
    });
  }

  /// The latest page of [feed]'s chat, replacing what it had.
  Future<void> _loadLatest(_Feed feed) async {
    final result = await _messages(feed.chatId, limit: chatPageSize);
    if (feed.changes.isClosed) return;
    switch (result) {
      case Success(value: (:final messages, truncated: _)):
        // Events that came during the first load are newer than the page;
        // a reload (after too much was missed) starts afresh.
        final arrived = feed.loaded ? const <Message>[] : [...feed.messages];
        feed
          ..messages.clear()
          ..addAll(messages)
          ..addAll(arrived)
          ..loaded = true
          ..emit();
      case Err(:final failure):
        feed.changes.addError(failure);
    }
  }

  Future<Result<({List<Message> messages, bool truncated})>> _messages(
    String chatId, {
    String? before,
    String? after,
    int? limit,
  }) =>
      gateway.rpc(
        'get_messages',
        (json) {
          final map = json! as Map<String, dynamic>;
          return (
            messages: listOf(Message.fromJson)(map['messages']),
            truncated: map['truncated'] == true,
          );
        },
        params: {
          'p_chat_id': chatId,
          'p_before': ?before,
          'p_after': ?after,
          'p_limit': ?limit,
        },
      );

  @override
  Future<Result<List<Message>>> loadOlder(
    String chatId, {
    required String before,
  }) async {
    final result = await _messages(
      chatId,
      before: before,
      limit: chatPageSize,
    );
    return result.when(
      success: (page) => Success(page.messages),
      failure: Err.new,
    );
  }

  // ── Events and catching up ─────────────────────────────────

  void _onEvent(ChatEvent event) {
    switch (event) {
      case MessageCreated(:final chatId, :final message):
        _feeds[chatId]
          ?..addAll([message])
          ..emit();
      case MessagesRead(:final chatId, :final upTo):
        _feeds[chatId]?.markRead(upTo, by: userId);
        final chat = _chats?.where((c) => c.id == chatId).firstOrNull;
        if (chat?.lastMessage case final last?
            when last.id == upTo && last.senderId == userId) {
          _upsertChat(
            chat!.copyWith(
              lastMessage: last.copyWith(status: MessageStatus.read),
            ),
          );
        }
      case MessageListened():
        // «Listened» on one's own voice notes isn't shown yet.
        break;
      case ChatUpdated(:final chat):
        _upsertChat(chat);
      case ChatRemoved(:final chatId):
        if (_chats case final chats?) {
          _setChats([
            for (final c in chats)
              if (c.id != chatId) c,
          ]);
        }
        _feeds[chatId]?.changes.addError(
              Failure(
                FailureCode.forbidden,
                message: 'Removed from chat $chatId',
              ),
            );
    }
  }

  /// The app is in front again: a channel found down is joined again (its
  /// rejoin catches up); otherwise catch up right away, in case anything
  /// slipped by while the app was asleep.
  Future<void> onAppResumed() async {
    final events = this.events;
    if (!_started || events == null) return;
    if (events.isJoined) {
      await catchUp();
    } else {
      await events.reconnect();
    }
  }

  /// Loads what the events may have missed: the chats, and the messages
  /// after the last known one of every open chat. Calls while one runs
  /// make it run once more after it.
  Future<void> catchUp() async {
    if (_catchingUp case final running?) {
      _catchUpAgain = true;
      return running;
    }
    final run = _catchingUp = () async {
      do {
        _catchUpAgain = false;
        await Future.wait([
          // Also a list whose first load failed, e.g. started offline.
          if (_chats != null || _chatsChanged.hasListener) _loadChats(),
          for (final feed in [..._feeds.values]) _catchUpFeed(feed),
        ]);
      } while (_catchUpAgain);
    }();
    try {
      await run;
    } finally {
      _catchingUp = null;
    }
  }

  Future<void> _catchUpFeed(_Feed feed) async {
    final last = feed.messages.lastOrNull;
    if (!feed.loaded || last == null) return _loadLatest(feed);
    final result = await _messages(feed.chatId, after: last.id);
    if (feed.changes.isClosed) return;
    switch (result) {
      case Success(value: (:final messages, :final truncated)):
        // Too much was missed: start again from the latest page.
        if (truncated) return _loadLatest(feed);
        feed
          ..addAll(messages)
          ..emit();
      case Err(:final failure):
        // Not a member any more; a network error waits for the next try.
        if (failure.code == FailureCode.forbidden ||
            failure.code == FailureCode.notFound) {
          feed.changes.addError(failure);
        }
    }
  }

  // ── Sending ────────────────────────────────────────────────

  @override
  Future<Result<MessageAttachment>> uploadPhoto(
    CompressedPhoto photo, {
    ValueChanged<double>? onProgress,
  }) async {
    if (userId == null) return const Err(_noSession);
    final uploaded = await uploads.photo(photo, onProgress: onProgress);
    return uploaded.when(
      success: (file) => Success(
        MessageAttachment(
          id: file.attachmentId,
          url: file.ref.url,
          width: photo.width,
          height: photo.height,
          mime: 'image/jpeg',
        ),
      ),
      failure: Err.new,
    );
  }

  @override
  Future<Result<MessageAttachment>> uploadVoice(
    VoiceNote note, {
    ValueChanged<double>? onProgress,
  }) async {
    if (userId == null) return const Err(_noSession);
    final int bytes;
    try {
      bytes = await File(note.path).length();
    } on FileSystemException catch (e, stackTrace) {
      return Err(
        Failure(FailureCode.unknown, message: '$e', stackTrace: stackTrace),
      );
    }
    final uploaded = await uploads.voice(
      note,
      bytes: bytes,
      onProgress: onProgress,
    );
    return uploaded.when(
      success: (file) {
        _voiceUploads.add(file.attachmentId);
        return Success(
          MessageAttachment(
            id: file.attachmentId,
            url: file.ref.url,
            durationMs: note.duration.inMilliseconds,
            waveform: note.waveform,
            mime: VoiceNote.mime,
          ),
        );
      },
      failure: Err.new,
    );
  }

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  }) async {
    final kind = switch (attachmentIds) {
      [] => MessageKind.text,
      [final id] when _voiceUploads.contains(id) => MessageKind.voice,
      _ => MessageKind.photo,
    };
    final trimmed = text.trim();
    final result = await gateway.rpc(
      'send_message',
      one(Message.fromJson),
      params: {
        'p_chat_id': chatId,
        'p_client_id': clientId,
        'p_kind': kind.name,
        if (trimmed.isNotEmpty) 'p_text': trimmed,
        if (attachmentIds.isNotEmpty) 'p_attachment_ids': attachmentIds,
      },
    );
    if (result case Success(value: final message)) {
      _feeds[chatId]
        ?..addAll([message])
        ..emit();
    }
    return result;
  }

  @override
  Future<Result<Chat>> getOrCreateDirect(String userId) async {
    final result = await gateway.rpc(
      'get_or_create_direct',
      one(Chat.fromJson),
      params: {'p_user_id': userId},
    );
    if (result case Success(value: final chat)) _upsertChat(chat);
    return result;
  }

  @override
  Future<Result<void>> markListened(
    String chatId, {
    required String messageId,
  }) =>
      gateway.rpc(
        'mark_listened',
        (_) {},
        params: {'p_chat_id': chatId, 'p_message_id': messageId},
      );

  @override
  Future<Result<void>> markRead(String chatId, {required String upTo}) =>
      gateway.rpc(
        'mark_read',
        (_) {},
        params: {'p_chat_id': chatId, 'p_up_to': upTo},
      );

  /// Leaves the channel: on sign-out and when the user changes.
  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await events?.dispose();
    await _chatsChanged.close();
    for (final feed in _feeds.values) {
      await feed.changes.close();
    }
    _feeds.clear();
  }
}

/// The messages of one open chat in the server's order, from its latest
/// page on, with what came since.
class _Feed {
  _Feed(this.chatId);

  final String chatId;
  final changes = StreamController<List<Message>>.broadcast();
  final List<Message> messages = [];
  bool loaded = false;
  int listeners = 0;

  /// The latest page, as `watchMessages` promises.
  List<Message> get latest => messages.length <= chatPageSize
      ? List.unmodifiable(messages)
      : List.unmodifiable(messages.sublist(messages.length - chatPageSize));

  /// Adds new messages, or newer versions of known ones; a repeated
  /// event changes nothing.
  void addAll(List<Message> incoming) {
    for (final m in incoming) {
      final i = messages.indexWhere((known) => known.id == m.id);
      if (i == -1) {
        messages.add(m);
      } else {
        messages[i] = m;
      }
    }
  }

  /// The user's messages up to [upTo] are read.
  void markRead(String upTo, {required String? by}) {
    final end = messages.indexWhere((m) => m.id == upTo);
    if (end == -1) return;
    for (var i = 0; i <= end; i++) {
      final m = messages[i];
      if (m.senderId == by && m.status == MessageStatus.sent) {
        messages[i] = m.copyWith(status: MessageStatus.read);
      }
    }
    emit();
  }

  void emit() {
    if (loaded && !changes.isClosed) changes.add(latest);
  }
}
