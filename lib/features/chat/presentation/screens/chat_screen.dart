import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/role_label.dart';
import 'package:buildflow/features/chat/domain/chat_timeline.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/presentation/chat_texts.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:buildflow/features/chat/presentation/widgets/chat_composer.dart';
import 'package:buildflow/features/chat/presentation/widgets/message_bubble.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One chat: messages with day dividers and author groups, the message
/// field below.
///
/// The list is a reversed `CustomScrollView` centered on the history
/// sliver: the history grows upwards, messages that arrive while the user
/// reads above the bottom go into a sliver below the center, so they never
/// push the text the user is reading. Instead the «Новые сообщения» pill
/// shows up.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.chatId, super.key});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _historyKey = ValueKey('history');

  /// Closer to the bottom than this counts as being at the bottom.
  static const _bottomSlack = 48.0;

  /// Older messages load when the top is closer than this.
  static const _loadOlderSlack = 400.0;

  final _scroll = ScrollController();

  /// clientId of the newest message in the history sliver; the messages
  /// after it are in the sliver below the center.
  String? _anchor;
  bool _newBelow = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    ref.listenManual(
      chatThreadProvider(widget.chatId),
      _onThread,
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ChatThreadNotifier get _notifier =>
      ref.read(chatThreadProvider(widget.chatId).notifier);

  bool get _atBottom =>
      !_scroll.hasClients ||
      _scroll.offset <= _scroll.position.minScrollExtent + _bottomSlack;

  void _onThread(AsyncValue<ChatThread>? previous, AsyncValue<ChatThread> next) {
    final thread = next.valueOrNull;
    if (thread == null) return;
    final latest = thread.messages.lastOrNull;
    final before = previous?.valueOrNull?.messages.lastOrNull;

    if (_anchor == null) {
      _anchor = latest?.clientId;
    } else if (latest != null && latest.clientId != before?.clientId) {
      final mine = latest.senderId == ref.read(currentUserProvider)?.id;
      if (mine || _atBottom) {
        _showLatest(latest.clientId);
      } else {
        setState(() => _newBelow = true);
      }
    }

    // Reading the chat: on opening and on every new message while open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.markRead();
      // A short history may not fill the screen: load more right away.
      if (thread.hasMore &&
          _scroll.hasClients &&
          _scroll.position.maxScrollExtent <= 0) {
        _notifier.loadOlder();
      }
    });
  }

  /// Moves every message into the history sliver and shows the bottom.
  void _showLatest(String? clientId) {
    if (!mounted) return;
    setState(() {
      _anchor = clientId;
      _newBelow = false;
    });
    if (_scroll.hasClients && _scroll.offset != 0) _scroll.jumpTo(0);
  }

  Future<void> _scrollToLatest() async {
    if (_scroll.hasClients) {
      await _scroll.animateTo(
        _scroll.position.minScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    final latest = ref
        .read(chatThreadProvider(widget.chatId))
        .valueOrNull
        ?.messages
        .lastOrNull;
    _showLatest(latest?.clientId);
  }

  void _onScroll() {
    if (_newBelow && _atBottom) setState(() => _newBelow = false);
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadOlderSlack) {
      _notifier.loadOlder();
    }
  }

  Future<void> _openFailedMenu(Message message) async {
    final l10n = AppLocalizations.of(context);
    final t = context.bfTheme;
    final retry = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                0,
                AppTheme.screenPadding,
                AppTheme.spacing8,
              ),
              child: Text(
                l10n.messageFailed,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.retry),
              onTap: () => Navigator.pop(sheetContext, true),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: t.danger.fg),
              title: Text(
                l10n.delete,
                style: TextStyle(color: t.danger.fg),
              ),
              onTap: () => Navigator.pop(sheetContext, false),
            ),
          ],
        ),
      ),
    );
    if (!mounted || retry == null) return;
    if (retry) {
      await _notifier.retry(message.clientId);
    } else {
      _notifier.discard(message.clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final thread = ref.watch(chatThreadProvider(widget.chatId));
    final chat = ref.watch(chatByIdProvider(widget.chatId)).valueOrNull;
    final me = ref.watch(currentUserProvider)?.id;
    final members = ref.watch(membersProvider).valueOrNull;
    final peerId = me == null ? null : chat?.peerOf(me);
    final peer = peerId == null
        ? null
        : members?.where((m) => m.userId == peerId).firstOrNull;
    // Known only once the members are loaded.
    final peerLeft = peerId != null && members != null && peer == null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: chat == null ? null : _ChatHeader(chat: chat, peer: peer),
      ),
      body: thread.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => switch (error) {
          Failure(code: FailureCode.forbidden || FailureCode.notFound) =>
            EmptyState(
              icon: Icons.lock_outline_rounded,
              title: l10n.chatUnavailable,
              description: l10n.chatUnavailableHint,
            ),
          _ => ErrorState(
              message: l10n.failureMessage(error),
              onRetry: () => ref.invalidate(chatThreadProvider(widget.chatId)),
              retryLabel: l10n.retry,
            ),
        },
        data: (thread) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: thread.messages.isEmpty
                        ? EmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: l10n.chatNoMessages,
                            description: peerLeft ? null : l10n.chatEmptyHint,
                          )
                        : _messages(thread, chat, me),
                  ),
                  if (_newBelow)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppTheme.spacing12,
                      child: Center(
                        child: _NewMessagesPill(onTap: _scrollToLatest),
                      ),
                    ),
                ],
              ),
            ),
            if (peerLeft)
              _ReadOnlyNote(text: l10n.peerLeftCompany)
            else
              ChatComposer(
                onSend: (text) => _notifier.send(text),
              ),
          ],
        ),
      ),
    );
  }

  Widget _messages(ChatThread thread, Chat? chat, String? me) {
    final items = buildTimeline(thread.messages);
    final anchorIndex = _anchor == null
        ? -1
        : items.lastIndexWhere(
            (item) => item is MessageEntry && item.message.clientId == _anchor,
          );
    final split = anchorIndex == -1 ? items.length : anchorIndex + 1;
    final history = items.sublist(0, split);
    final newer = items.sublist(split);
    final isProject = chat?.type.isProject ?? false;

    Widget row(TimelineItem item) => _TimelineRow(
          item: item,
          me: me,
          isProject: isProject,
          onFailedTap: _openFailedMenu,
        );

    return CustomScrollView(
      controller: _scroll,
      reverse: true,
      center: _historyKey,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        // Before the center: laid out downwards from it, last one lowest.
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing12)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => row(newer[i]),
            childCount: newer.length,
          ),
        ),
        // The center: laid out upwards, newest first.
        SliverList(
          key: _historyKey,
          delegate: SliverChildBuilderDelegate(
            (_, i) => row(history[history.length - 1 - i]),
            childCount: history.length,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Center(
              child: thread.isLoadingOlder
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rows ──────────────────────────────────────────────────────

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({
    required this.item,
    required this.me,
    required this.isProject,
    required this.onFailedTap,
  });

  final TimelineItem item;
  final String? me;
  final bool isProject;
  final ValueChanged<Message> onFailedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final names = ref.watch(memberNamesProvider);

    return switch (item) {
      DayDivider(:final day) => Padding(
          padding: const EdgeInsets.only(
            top: AppTheme.spacing16,
            bottom: AppTheme.spacing4,
          ),
          child: DayDividerPill(
            label: DateFormatter.chatDay(
              day,
              today: l10n.today,
              yesterday: l10n.yesterday,
            ),
          ),
        ),
      MessageEntry(:final message) when message.kind == MessageKind.system =>
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacing12),
          child: SystemMessageLine(text: l10n.messageSummary(message, names)),
        ),
      MessageEntry(:final message, :final firstInGroup, :final lastInGroup) =>
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.spacing12,
            firstInGroup ? 10 : 2,
            AppTheme.spacing12,
            0,
          ),
          child: MessageBubble(
            message: message,
            text: l10n.messageSummary(message, names),
            mine: message.senderId == me,
            firstInGroup: firstInGroup,
            lastInGroup: lastInGroup,
            senderName: isProject && message.senderId != me
                ? l10n.memberName(names, message.senderId)
                : null,
            onFailedTap: () => onFailedTap(message),
          ),
        ),
    };
  }
}

// ── Header and overlays ───────────────────────────────────────

/// Chat picture, title and «8 участников» or the other person's role.
/// A project chat's header opens the project.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.chat, this.peer});

  final Chat chat;
  final Member? peer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final subtitle = chat.type.isProject
        ? l10n.chatParticipants(chat.participantIds.length)
        : peer?.role.label(l10n);
    final projectId = chat.projectId;

    final content = Row(
      children: [
        ChatAvatar(chat: chat, size: 40),
        const SizedBox(width: AppTheme.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.chatTitle(chat),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.bfTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (projectId == null) return content;
    return InkWell(
      onTap: () => context.push(Routes.project(projectId)),
      child: SizedBox(height: kToolbarHeight, child: content),
    );
  }
}

class _NewMessagesPill extends StatelessWidget {
  const _NewMessagesPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Material(
      color: t.graphite,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).newMessagesBelow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: t.onGraphite,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: AppTheme.spacing4),
                Icon(Icons.arrow_downward_rounded, size: 18, color: t.onGraphite),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// In place of the message field when nobody can receive the messages.
class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: t.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}
