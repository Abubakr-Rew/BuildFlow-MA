import 'dart:async';

import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/data/api_chat_repository.dart';
import 'package:buildflow/features/chat/data/fake_chat_repository.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/chat/presentation/providers/fake_chat_store_provider.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// ── DI ───────────────────────────────────────────────────────

/// Bound to the signed-in user: the fake needs the id, the API will take
/// the user from the token.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => kUseMockData
      ? FakeChatRepository(
          store: ref.watch(fakeChatStoreProvider),
          userId: ref.watch(currentUserProvider.select((u) => u?.id)),
          sendFailureRate: kFakeChatSendFailureRate,
        )
      : ApiChatRepository(),
);

// ── Chat list ────────────────────────────────────────────────

/// The user's chats as the server sends them, live, latest activity first.
/// Direct chats have no title here; screens read [chatListProvider].
final chatsProvider = StreamNotifierProvider<ChatsNotifier, List<Chat>>(
  ChatsNotifier.new,
);

class ChatsNotifier extends StreamNotifier<List<Chat>> {
  @override
  Stream<List<Chat>> build() {
    final user = ref.watch(currentUserProvider);
    if (user == null) return Stream.value(const []);
    return ref.watch(chatRepositoryProvider).watchChats();
  }

  /// The direct chat with [userId], created on first use. The chat list
  /// picks it up from the stream.
  Future<Result<Chat>> openDirect(String userId) =>
      ref.read(chatRepositoryProvider).getOrCreateDirect(userId);
}

/// [chatsProvider] with the titles of direct chats filled in: the other
/// person's name, or empty if they are no longer in the company. Loading
/// until the members are known, so the names don't pop in.
final chatListProvider = Provider<AsyncValue<List<Chat>>>((ref) {
  final chats = ref.watch(chatsProvider);
  final members = ref.watch(membersProvider);
  final me = ref.watch(currentUserProvider)?.id;
  if (chats.hasValue && !members.hasValue && members.isLoading) {
    return const AsyncLoading();
  }
  final names = {
    for (final m in members.valueOrNull ?? const <Member>[]) m.userId: m.name,
  };
  return chats.whenData(
    (list) => [
      for (final chat in list)
        if (chat.type.isDirect && me != null)
          chat.copyWith(title: names[chat.peerOf(me)] ?? '')
        else
          chat,
    ],
  );
});

/// A chat of the user by id; `null` if they aren't in it.
final chatByIdProvider = Provider.family<AsyncValue<Chat?>, String>(
  (ref, id) => ref
      .watch(chatListProvider)
      .whenData((chats) => chats.where((c) => c.id == id).firstOrNull),
);

/// The chat of the project, if the user is in the project team.
final projectChatProvider = Provider.family<Chat?, String>(
  (ref, projectId) => ref
      .watch(chatsProvider)
      .valueOrNull
      ?.where((c) => c.projectId == projectId)
      .firstOrNull,
);

/// Unread messages over all chats: the badge of the «Чаты» tab.
final totalUnreadProvider = Provider<int>(
  (ref) =>
      ref
          .watch(chatsProvider)
          .valueOrNull
          ?.fold<int>(0, (sum, c) => sum + c.unreadCount) ??
      0,
);

// ── Messages of one chat ─────────────────────────────────────

/// Messages of an open chat, oldest first: the live last page, older pages
/// loaded on scroll, then the user's messages still sending or failed.
@immutable
class ChatThread {
  const ChatThread({
    required this.messages,
    this.hasMore = false,
    this.isLoadingOlder = false,
  });

  final List<Message> messages;

  /// Whether older messages can be loaded.
  final bool hasMore;
  final bool isLoadingOlder;
}

final chatThreadProvider = AsyncNotifierProvider.autoDispose
    .family<ChatThreadNotifier, ChatThread, String>(ChatThreadNotifier.new);

class ChatThreadNotifier
    extends AutoDisposeFamilyAsyncNotifier<ChatThread, String> {
  static const _uuid = Uuid();

  late ChatRepository _repo;
  String? _userId;

  /// Server messages by id: every live and older page seen so far, so a
  /// message that slides out of the live page stays on screen.
  final Map<String, Message> _known = {};

  /// The user's messages not yet confirmed by the server, by clientId.
  final Map<String, Message> _outbox = {};
  bool? _hasMore;
  bool _loadingOlder = false;
  String? _lastMarked;
  bool _disposed = false;

  @override
  Future<ChatThread> build(String chatId) {
    _repo = ref.watch(chatRepositoryProvider);
    _userId = ref.watch(currentUserProvider.select((u) => u?.id));
    _known.clear();
    _outbox.clear();
    _hasMore = null;
    _loadingOlder = false;
    _lastMarked = null;
    _disposed = false;

    final first = Completer<ChatThread>();
    final subscription = _repo.watchMessages(chatId).listen(
      (messages) {
        for (final m in messages) {
          _known[m.id] = m;
        }
        _hasMore ??= messages.length >= chatPageSize;
        final delivered = {for (final m in messages) m.clientId};
        _outbox.removeWhere((clientId, _) => delivered.contains(clientId));
        final thread = _compose();
        if (first.isCompleted) {
          if (!_disposed) state = AsyncData(thread);
        } else {
          first.complete(thread);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (first.isCompleted) {
          if (!_disposed) state = AsyncError(error, stackTrace);
        } else {
          first.completeError(error, stackTrace);
        }
      },
    );
    ref.onDispose(() {
      _disposed = true;
      unawaited(subscription.cancel());
    });
    return first.future;
  }

  List<Message> get _serverMessages => _known.values.toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

  ChatThread _compose() => ChatThread(
        messages: [..._serverMessages, ..._outbox.values],
        hasMore: _hasMore ?? false,
        isLoadingOlder: _loadingOlder,
      );

  void _emit() {
    if (_disposed || state.hasError || !state.hasValue) return;
    state = AsyncData(_compose());
  }

  /// Shows the message at once as «sending», then as sent or failed.
  Future<Result<Message>> send(String text) async {
    final trimmed = text.trim();
    final userId = _userId;
    if (trimmed.isEmpty) {
      return const Err(
        Failure(FailureCode.validation, message: 'Empty message'),
      );
    }
    if (userId == null) {
      return const Err(
        Failure(FailureCode.sessionExpired, message: 'Not signed in'),
      );
    }
    final clientId = _uuid.v4();
    final pending = Message(
      id: clientId,
      clientId: clientId,
      chatId: arg,
      senderId: userId,
      kind: MessageKind.text,
      text: trimmed,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    _outbox[clientId] = pending;
    _emit();
    return _deliver(pending);
  }

  /// Sends a failed message again with the same clientId, so the server
  /// can't create it twice.
  Future<Result<Message>> retry(String clientId) async {
    final failed = _outbox[clientId];
    if (failed == null || !failed.status.isFailed) {
      return Err(
        Failure(FailureCode.notFound, message: 'No failed message $clientId'),
      );
    }
    final pending = failed.copyWith(status: MessageStatus.sending);
    _outbox[clientId] = pending;
    _emit();
    return _deliver(pending);
  }

  /// Drops a failed message.
  void discard(String clientId) {
    if (_outbox[clientId]?.status.isFailed ?? false) {
      _outbox.remove(clientId);
      _emit();
    }
  }

  Future<Result<Message>> _deliver(Message pending) async {
    final clientId = pending.clientId;
    final result = await _repo.send(
      arg,
      text: pending.text ?? '',
      clientId: clientId,
    );
    if (_disposed) return result;
    switch (result) {
      case Success(:final data):
        _outbox.remove(clientId);
        _known.putIfAbsent(data.id, () => data);
      case Err():
        if (_outbox.containsKey(clientId)) {
          _outbox[clientId] = pending.copyWith(status: MessageStatus.failed);
        }
    }
    _emit();
    return result;
  }

  /// Loads the page before the oldest known message.
  Future<Result<void>> loadOlder() async {
    final oldest = _serverMessages.firstOrNull;
    if (_hasMore != true || _loadingOlder || oldest == null) {
      return const Success(null);
    }
    _loadingOlder = true;
    _emit();
    final result = await _repo.loadOlder(arg, before: oldest.id);
    if (_disposed) return result;
    _loadingOlder = false;
    if (result case Success(:final data)) {
      for (final m in data) {
        _known.putIfAbsent(m.id, () => m);
      }
      _hasMore = data.length >= chatPageSize;
    }
    _emit();
    return result;
  }

  /// Marks the chat read up to the latest message, if it came from someone
  /// else and isn't marked yet. Sending marks the chat read by itself.
  Future<Result<void>> markRead() async {
    final latest = _serverMessages.lastOrNull;
    if (latest == null ||
        latest.senderId == _userId ||
        latest.id == _lastMarked) {
      return const Success(null);
    }
    _lastMarked = latest.id;
    final result = await _repo.markRead(arg, upTo: latest.id);
    if (result.isFailure && _lastMarked == latest.id) _lastMarked = null;
    return result;
  }
}
