import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/bf_chip.dart';
import 'package:buildflow/core/widgets/bf_icon_button.dart';
import 'package:buildflow/core/widgets/bf_text_field.dart';
import 'package:buildflow/core/widgets/empty_state.dart';
import 'package:buildflow/core/widgets/error_state.dart';
import 'package:buildflow/core/widgets/highlighted_text.dart';
import 'package:buildflow/core/widgets/loading_shimmer.dart';
import 'package:buildflow/core/widgets/screen_header.dart';
import 'package:buildflow/core/widgets/unread_badge.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/domain/chat_search.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/presentation/chat_texts.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The «Чаты» tab: project chats and direct chats, latest activity first,
/// with search by project or person and a type filter.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _controller = TextEditingController();

  /// `null` shows every chat.
  ChatType? _type;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chats = ref.watch(chatListProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: l10n.chatsTitle,
              actions: [
                BfIconButton(
                  icon: Icons.person_search_rounded,
                  tooltip: l10n.newDirectChat,
                  onPressed: () => context.push(Routes.peopleSearch),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: BfTextField(
                label: l10n.searchChats,
                controller: _controller,
                prefixIcon: Icons.search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearSearch,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_controller.clear),
                      ),
              ),
            ),
            const SizedBox(height: AppTheme.spacing4),
            _TypeFilter(
              selected: _type,
              onSelected: (type) => setState(() => _type = type),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(chatsProvider)
                    ..invalidate(membersProvider);
                  await ref.read(chatsProvider.future);
                },
                child: chats.when(
                  loading: () => const LoadingShimmerList(),
                  error: (error, _) => _Fill(
                    child: ErrorState(
                      message: l10n.failureMessage(error),
                      onRetry: () => ref.invalidate(chatsProvider),
                      retryLabel: l10n.retry,
                    ),
                  ),
                  data: _buildList,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Chat> chats) {
    final l10n = AppLocalizations.of(context);
    if (chats.isEmpty) {
      return _Fill(
        child: EmptyState(
          icon: Icons.forum_outlined,
          title: l10n.noChats,
          description: l10n.noChatsHint,
        ),
      );
    }

    final titled = [for (final c in chats) c.copyWith(title: l10n.chatTitle(c))];
    final matches = searchChats(titled, _controller.text, type: _type);
    if (matches.isEmpty) {
      return _Fill(
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.noChatsFound,
          description: l10n.noChatsFoundHint,
        ),
      );
    }

    final me = ref.watch(currentUserProvider)?.id;
    final names = ref.watch(memberNamesProvider);
    final t = context.bfTheme;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
      itemCount: matches.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: t.border,
        indent: AppTheme.screenPadding + _ChatRow.avatarSize + 12,
        endIndent: AppTheme.screenPadding,
      ),
      itemBuilder: (_, i) {
        final match = matches[i];
        return _ChatRow(
          chat: match.chat,
          ranges: match.ranges,
          preview: l10n.chatPreview(match.chat, me, names),
          onTap: () => context.push(Routes.chat(match.chat.id)),
        );
      },
    );
  }
}

// ── Filter ────────────────────────────────────────────────────

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.selected, required this.onSelected});

  final ChatType? selected;
  final ValueChanged<ChatType?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = <(ChatType?, String)>[
      (null, l10n.chatFilterAll),
      (ChatType.project, l10n.chatFilterProjects),
      (ChatType.direct, l10n.chatFilterDirect),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: [
          for (final (i, (type, label)) in options.indexed) ...[
            if (i > 0) const SizedBox(width: AppTheme.spacing8),
            BfChip(
              label: label,
              selected: selected == type,
              onTap: () => onSelected(type),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.ranges,
    required this.preview,
    required this.onTap,
  });

  static const avatarSize = 52.0;

  final Chat chat;
  final List<({int start, int end})> ranges;
  final ({String prefix, String text, bool isPhoto}) preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final unread = chat.unreadCount > 0;
    final time = chat.lastMessage?.createdAt ?? chat.updatedAt;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            ChatAvatar(chat: chat),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: HighlightedText(
                          text: chat.title,
                          ranges: ranges,
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        DateFormatter.chatListTime(
                          time,
                          yesterday: l10n.yesterday,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unread ? t.accentText : t.textTertiary,
                          fontWeight: unread ? FontWeight.w700 : null,
                          fontFeatures: AppTextTheme.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: _Preview(
                          preview: preview,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: unread ? t.textPrimary : t.textSecondary,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        UnreadBadge(count: chat.unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Бакыт: текст», or «Бакыт: 📷 3 фото · подпись» with a photo icon.
class _Preview extends StatelessWidget {
  const _Preview({required this.preview, required this.style});

  final ({String prefix, String text, bool isPhoto}) preview;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (!preview.isPhoto) {
      return Text(
        '${preview.prefix}${preview.text}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: preview.prefix),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacing4),
              child: Icon(
                Icons.photo_camera_outlined,
                size: 16,
                color: style?.color,
              ),
            ),
          ),
          TextSpan(text: preview.text),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Lets a state view fill the list area and still pull to refresh.
class _Fill extends StatelessWidget {
  const _Fill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
