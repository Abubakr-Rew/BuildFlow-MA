import 'dart:async';

import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Events ───────────────────────────────────────────────────

/// What the server says about the user's chats, as it happens
/// (docs/api-contract.md, «Реальное время»; docs/supabase-plan.md).
sealed class ChatEvent {
  const ChatEvent();

  /// The event types, also the broadcast event names of the channel.
  static const types = [
    'message.created',
    'message.status',
    'message.listened',
    'chat.updated',
    'chat.removed',
  ];

  /// The body of an event (`{"type": "message.created", "chatId": …}`);
  /// `null` for a type this version doesn't know.
  static ChatEvent? fromJson(Map<String, dynamic> json) =>
      switch (json['type']) {
        'message.created' => MessageCreated(
            chatId: json['chatId'] as String,
            message: Message.fromJson(json['message'] as Map<String, dynamic>),
          ),
        'message.status' => MessagesRead(
            chatId: json['chatId'] as String,
            upTo: json['upTo'] as String,
          ),
        'message.listened' => MessageListened(
            chatId: json['chatId'] as String,
            messageId: json['messageId'] as String,
            userId: json['userId'] as String,
          ),
        'chat.updated' => ChatUpdated(
            Chat.fromJson(json['chat'] as Map<String, dynamic>),
          ),
        'chat.removed' => ChatRemoved(json['chatId'] as String),
        _ => null,
      };
}

/// A new message, the user's own (from another device) included.
class MessageCreated extends ChatEvent {
  const MessageCreated({required this.chatId, required this.message});

  final String chatId;
  final Message message;
}

/// Someone else read the user's messages up to [upTo] inclusive.
class MessagesRead extends ChatEvent {
  const MessagesRead({required this.chatId, required this.upTo});

  final String chatId;
  final String upTo;
}

/// Someone played the user's voice note.
class MessageListened extends ChatEvent {
  const MessageListened({
    required this.chatId,
    required this.messageId,
    required this.userId,
  });

  final String chatId;
  final String messageId;
  final String userId;
}

/// A chat as the user sees it now: a new chat, a new title, members, unread
/// count or last message.
class ChatUpdated extends ChatEvent {
  const ChatUpdated(this.chat);

  final Chat chat;
}

/// The user left the chat: removed from the project or the company.
class ChatRemoved extends ChatEvent {
  const ChatRemoved(this.chatId);

  final String chatId;
}

// ── The channel ──────────────────────────────────────────────

/// The user's event channel. Events missed while it was down aren't
/// replayed: whoever listens catches up when [rejoined] fires.
abstract class ChatEvents {
  Stream<ChatEvent> get events;

  /// Fires when the channel is joined again after it was down (lost
  /// connection, the app back from the background).
  Stream<void> get rejoined;

  /// Whether the channel is joined now.
  bool get isJoined;

  /// Joins the channel; nothing if it already is.
  void connect();

  /// Leaves and joins again, e.g. when the app comes back and finds the
  /// channel down; [rejoined] fires once it's in.
  Future<void> reconnect();

  /// Leaves the channel for good: on sign-out or another user.
  Future<void> dispose();
}

/// [ChatEvents] over the private Realtime channel `user:<id>`: the
/// database broadcasts every event for the user there, and only they may
/// join it.
class SupabaseChatEvents implements ChatEvents {
  SupabaseChatEvents(this.client, {required this.userId});

  final SupabaseClient client;
  final String userId;

  final _events = StreamController<ChatEvent>.broadcast();
  final _rejoined = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  bool _joined = false;

  /// Joined at least once, or failed to join (started offline): the next
  /// join is a rejoin, and what was missed meanwhile gets loaded.
  bool _wasJoined = false;
  bool _disposed = false;

  @override
  Stream<ChatEvent> get events => _events.stream;

  @override
  Stream<void> get rejoined => _rejoined.stream;

  @override
  bool get isJoined => _joined;

  @override
  void connect() {
    if (_channel != null || _disposed) return;
    final channel = client.channel(
      'user:$userId',
      opts: const RealtimeChannelConfig(private: true),
    );
    for (final type in ChatEvent.types) {
      channel.onBroadcast(event: type, callback: _onBroadcast);
    }
    channel.subscribe((status, error) {
      if (_disposed || !identical(channel, _channel)) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          final again = _wasJoined;
          _joined = _wasJoined = true;
          if (again) _rejoined.add(null);
        case RealtimeSubscribeStatus.channelError ||
              RealtimeSubscribeStatus.closed ||
              RealtimeSubscribeStatus.timedOut:
          _joined = false;
          _wasJoined = true;
          if (error != null) debugPrint('Chat channel: $status $error');
      }
    });
    _channel = channel;
  }

  /// The frame is `{event, payload: {type, chatId, …}}`.
  void _onBroadcast(Map<String, dynamic> frame) {
    final body = frame['payload'];
    try {
      final event = ChatEvent.fromJson(
        body is Map ? body.cast<String, dynamic>() : frame,
      );
      if (event != null && !_disposed) _events.add(event);
    } on Object catch (e) {
      debugPrint('Unreadable chat event: $e');
    }
  }

  @override
  Future<void> reconnect() async {
    await _leave();
    if (_disposed) return;
    // Whatever came while it was down is caught up after the join.
    _wasJoined = true;
    connect();
  }

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    _joined = false;
    if (channel != null) {
      try {
        await client.removeChannel(channel);
      } on Object catch (e) {
        debugPrint('Leaving the chat channel failed: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _leave();
    await _events.close();
    await _rejoined.close();
  }
}
