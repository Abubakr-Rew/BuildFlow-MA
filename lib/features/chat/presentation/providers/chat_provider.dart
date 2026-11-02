import 'dart:async';

import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/photos/photo_compressor.dart';
import 'package:buildflow/core/photos/photo_draft.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/supabase/supabase_providers.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/data/chat_events.dart';
import 'package:buildflow/features/chat/data/fake_chat_repository.dart';
import 'package:buildflow/features/chat/data/supabase_chat_repository.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/domain/repositories/chat_repository.dart';
import 'package:buildflow/features/chat/presentation/providers/fake_chat_store_provider.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

// ── DI ───────────────────────────────────────────────────────

/// Bound to the signed-in user: a new user gets a new repository, and the
/// old one leaves its realtime channel.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => switch (kBackend) {
    Backend.fake => FakeChatRepository(
        store: ref.watch(fakeChatStoreProvider),
        userId: ref.watch(currentUserProvider.select((u) => u?.id)),
        sendFailureRate: kFakeChatSendFailureRate,
      ),
    Backend.supabase => supabaseChatRepository(ref),
  },
);

/// Opens the realtime channel of a user; tests override it.
final chatEventsFactoryProvider = Provider<ChatEvents Function(String userId)>(
  (ref) {
    final client = ref.watch(supabaseGatewayProvider).client;
    return (userId) => SupabaseChatEvents(client, userId: userId);
  },
);

/// The chats of the signed-in user on Supabase, with their channel. When
/// the app comes back to the front, it checks the channel and catches up.
/// Public for tests, which run on the fake backend.
SupabaseChatRepository supabaseChatRepository(Ref ref) {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  final gateway = ref.watch(supabaseGatewayProvider);
  final repo = SupabaseChatRepository(
    gateway: gateway,
    uploads: SupabaseUploads(
      gateway,
      // A sent photo or note is what the server has: no download back.
      onUploaded: ref.watch(remoteFilesProvider).adopt,
    ),
    userId: userId,
    events: userId == null ? null : ref.watch(chatEventsFactoryProvider)(userId),
  );
  final lifecycle = AppLifecycleListener(
    onResume: () => unawaited(repo.onAppResumed()),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(repo.dispose());
  });
  return repo;
}

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
    return ref.watch(chatRepositoryProvider).watchChats().map((chats) {
      // Started without a connection, the members failed to load too:
      // with the chats back, so are the names of authors and peers.
      final members = ref.read(membersProvider);
      if (members.hasError && !members.isLoading) {
        ref.invalidate(membersProvider);
      }
      return chats;
    });
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

/// Names of the company's members by user id, for message authors and
/// previews. Empty while the members load.
final memberNamesProvider = Provider<Map<String, String>>(
  (ref) => {
    for (final m in ref.watch(membersProvider).valueOrNull ?? const <Member>[])
      m.userId: m.name,
  },
);

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
    this.uploadProgress = const {},
  });

  final List<Message> messages;

  /// Upload progress (0–1) of the photos of the user's messages being
  /// sent, by attachment id. A photo missing here is still being
  /// compressed or waits for its turn.
  final Map<String, double> uploadProgress;

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
  late PhotoCompressor _compressor;
  String? _userId;

  /// Server messages by id: every live and older page seen so far, so a
  /// message that slides out of the live page stays on screen.
  final Map<String, Message> _known = {};

  /// The user's messages not yet confirmed by the server, by clientId.
  final Map<String, Message> _outbox = {};

  /// The photos of the photo messages in [_outbox], by clientId.
  final Map<String, List<_OutgoingPhoto>> _photos = {};

  /// The notes of the voice messages in [_outbox], by clientId.
  final Map<String, _OutgoingVoice> _voices = {};

  /// Voice notes played here, shown as listened before the server says so.
  final Set<String> _listened = {};
  final Map<String, double> _progress = {};
  bool? _hasMore;
  bool _loadingOlder = false;
  String? _lastMarked;
  bool _disposed = false;

  @override
  Future<ChatThread> build(String chatId) {
    _repo = ref.watch(chatRepositoryProvider);
    _compressor = ref.watch(photoCompressorProvider);
    _userId = ref.watch(currentUserProvider.select((u) => u?.id));
    _known.clear();
    _outbox.clear();
    _photos.clear();
    _voices.clear();
    _listened.clear();
    _progress.clear();
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
        messages: [
          for (final m in _serverMessages)
            if (!m.listened && _listened.contains(m.id))
              m.copyWith(listened: true)
            else
              m,
          ..._outbox.values,
        ],
        hasMore: _hasMore ?? false,
        isLoadingOlder: _loadingOlder,
        uploadProgress: Map.unmodifiable(_progress),
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

  /// Sends photos handed over by the message field, with [caption]. The
  /// message shows at once as «sending» with the originals, waits for any
  /// compression still running, then uploads the photos one by one.
  Future<Result<Message>> sendPhotos(
    List<PhotoHandoff> photos, {
    String caption = '',
  }) async {
    final userId = _userId;
    if (photos.isEmpty || photos.length > maxPhotosPerMessage) {
      return Err(
        Failure(
          FailureCode.validation,
          message: '${photos.length} photos, 1–$maxPhotosPerMessage allowed',
        ),
      );
    }
    if (userId == null) {
      return const Err(
        Failure(FailureCode.sessionExpired, message: 'Not signed in'),
      );
    }
    final clientId = _uuid.v4();
    final outgoing = [
      for (final h in photos)
        _OutgoingPhoto(
          localId: h.draft.id,
          sourcePath: h.draft.sourcePath,
          compression: h.result,
          photo: h.draft.photo,
        ),
    ];
    final trimmed = caption.trim();
    final pending = Message(
      id: clientId,
      clientId: clientId,
      chatId: arg,
      senderId: userId,
      kind: MessageKind.photo,
      text: trimmed.isEmpty ? null : trimmed,
      attachments: [for (final p in outgoing) p.preview],
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    _outbox[clientId] = pending;
    _photos[clientId] = outgoing;
    _emit();
    return _deliver(pending);
  }

  /// Sends a recorded voice note: shown at once as «sending», uploaded
  /// with progress, then sent, through the same queue as photos.
  Future<Result<Message>> sendVoice(VoiceNote note) async {
    final userId = _userId;
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
      kind: MessageKind.voice,
      attachments: [
        MessageAttachment(
          id: clientId,
          url: note.path,
          durationMs: note.duration.inMilliseconds,
          waveform: note.waveform,
          mime: VoiceNote.mime,
        ),
      ],
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    _outbox[clientId] = pending;
    _voices[clientId] = _OutgoingVoice(note);
    _emit();
    return _deliver(pending);
  }

  /// The user played someone else's voice note: its dot goes at once, the
  /// server learns it in the background.
  Future<Result<void>> markListened(Message message) async {
    if (message.kind != MessageKind.voice ||
        message.listened ||
        message.senderId == _userId ||
        !_listened.add(message.id)) {
      return const Success(null);
    }
    _emit();
    final result = await _repo.markListened(arg, messageId: message.id);
    if (result.isFailure && !_disposed) {
      _listened.remove(message.id);
      _emit();
    }
    return result;
  }

  /// Sends a failed message again with the same clientId, so the server
  /// can't create it twice. Photos and voice notes already uploaded are
  /// not uploaded again.
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

  /// Drops a failed message, and the files of its photos.
  void discard(String clientId) {
    if (_outbox[clientId]?.status.isFailed ?? false) {
      _outbox.remove(clientId);
      final voice = _voices.remove(clientId);
      if (voice != null) {
        _progress.remove(clientId);
        unawaited(_compressor.delete([voice.note.path]));
      }
      final photos = _photos.remove(clientId) ?? const [];
      for (final p in photos) {
        _progress.remove(p.localId);
      }
      unawaited(
        _compressor.delete([
          for (final p in photos) ...[
            p.sourcePath,
            if (p.photo case final photo?) photo.path,
          ],
        ]),
      );
      _emit();
    }
  }

  Future<Result<Message>> _deliver(Message pending) async {
    final clientId = pending.clientId;
    final photos = _photos[clientId];
    final voice = _voices[clientId];
    final result = switch ((photos, voice)) {
      (final photos?, _) => await _deliverPhotos(clientId, photos),
      (_, final voice?) => await _deliverVoice(clientId, voice),
      _ => await _repo.send(arg, text: pending.text ?? '', clientId: clientId),
    };
    if (result.isSuccess && photos != null) {
      // The copies are the photos now; the originals are done with.
      unawaited(_compressor.delete([for (final p in photos) p.sourcePath]));
    }
    if (_disposed) return result;
    switch (result) {
      case Success(:final data):
        _outbox.remove(clientId);
        _photos.remove(clientId);
        _voices.remove(clientId);
        _progress.remove(clientId);
        for (final p in photos ?? const <_OutgoingPhoto>[]) {
          _progress.remove(p.localId);
        }
        _known.putIfAbsent(data.id, () => data);
      case Err():
        if (_outbox[clientId] case final current?) {
          _outbox[clientId] = current.copyWith(status: MessageStatus.failed);
        }
    }
    _emit();
    return result;
  }

  /// Compresses and uploads the photos not uploaded yet, then sends the
  /// message with all of them.
  Future<Result<Message>> _deliverPhotos(
    String clientId,
    List<_OutgoingPhoto> photos,
  ) async {
    final ids = <String>[];
    for (final p in photos) {
      if (p.uploaded case final uploaded?) {
        ids.add(uploaded.id);
        continue;
      }
      var compressed = p.photo;
      if (compressed == null) {
        final compression = p.compression ??= _compressor.compress(
          p.sourcePath,
        );
        switch (await compression) {
          case Success(:final data):
            compressed = p.photo = data;
            _showSizes(clientId, photos);
          case Err(:final failure):
            // A retry compresses again from the original.
            p.compression = null;
            return Err(failure);
        }
      }
      _progress[p.localId] = 0;
      _emit();
      final upload = await _repo.uploadPhoto(
        compressed,
        onProgress: (value) {
          _progress[p.localId] = value;
          _emit();
        },
      );
      switch (upload) {
        case Success(:final data):
          p.uploaded = data;
          _progress[p.localId] = 1;
          ids.add(data.id);
        case Err(:final failure):
          _progress.remove(p.localId);
          return Err(failure);
      }
    }
    final message = _outbox[clientId];
    return _repo.send(
      arg,
      text: message?.text ?? '',
      attachmentIds: ids,
      clientId: clientId,
    );
  }

  /// Uploads the note unless it already is, then sends it. Its progress
  /// is under the clientId, the pending attachment's id.
  Future<Result<Message>> _deliverVoice(
    String clientId,
    _OutgoingVoice voice,
  ) async {
    var uploaded = voice.uploaded;
    if (uploaded == null) {
      _progress[clientId] = 0;
      _emit();
      final upload = await _repo.uploadVoice(
        voice.note,
        onProgress: (value) {
          _progress[clientId] = value;
          _emit();
        },
      );
      switch (upload) {
        case Success(:final data):
          uploaded = voice.uploaded = data;
          _progress[clientId] = 1;
        case Err(:final failure):
          _progress.remove(clientId);
          return Err(failure);
      }
    }
    return _repo.send(
      arg,
      attachmentIds: [uploaded.id],
      clientId: clientId,
    );
  }

  /// Lays the pending bubble out by the photos' real sizes once known.
  void _showSizes(String clientId, List<_OutgoingPhoto> photos) {
    if (_outbox[clientId] case final message?) {
      _outbox[clientId] = message.copyWith(
        attachments: [for (final p in photos) p.preview],
      );
      _emit();
    }
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

/// A photo of a message on its way: compressed, then uploaded. A retry
/// skips the steps already done.
class _OutgoingPhoto {
  _OutgoingPhoto({
    required this.localId,
    required this.sourcePath,
    required this.compression,
    this.photo,
  });

  /// Its attachment id in the pending message.
  final String localId;
  final String sourcePath;

  /// Running or done; `null` after a failure, until the retry.
  Future<Result<CompressedPhoto>>? compression;
  CompressedPhoto? photo;
  MessageAttachment? uploaded;

  /// How the pending bubble shows it: the original, laid out by the size
  /// of the copy once that is known.
  MessageAttachment get preview => MessageAttachment(
        id: localId,
        url: sourcePath,
        width: photo?.width,
        height: photo?.height,
      );
}

/// A voice note of a message on its way; a retry doesn't upload it again.
class _OutgoingVoice {
  _OutgoingVoice(this.note);

  final VoiceNote note;
  MessageAttachment? uploaded;
}
