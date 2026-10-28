import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/theme/app_text_theme.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/app/theme/theme_extensions.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/avatar_initials.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:flutter/material.dart';

/// A text message. The user's own are `bubbleOwn` on the right with the
/// time and delivery ticks; others' are white cards on the left. In a project
/// chat others' messages carry the author's name above the first message
/// of a group and the avatar beside the last one.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.text,
    required this.mine,
    required this.firstInGroup,
    required this.lastInGroup,
    this.senderName,
    this.onFailedTap,
    super.key,
  });

  final Message message;

  /// What the bubble says: the text, or «Неподдерживаемое сообщение».
  final String text;
  final bool mine;
  final bool firstInGroup;
  final bool lastInGroup;

  /// Author of someone else's message in a project chat; `null` hides the
  /// name and the avatar column.
  final String? senderName;

  /// Opens «Повторить / Удалить» for a message that failed to send.
  final VoidCallback? onFailedTap;

  static const _radius = Radius.circular(18);
  static const _joined = Radius.circular(6);

  /// Widest a bubble gets, as a share of the screen.
  static const _maxWidthShare = 0.78;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final theme = Theme.of(context);
    final supported = message.kind.isSupported;

    // Bubbles of one group touch with small corners on the author's side.
    final top = firstInGroup ? _radius : _joined;
    final bottom = lastInGroup ? _radius : _joined;
    final radius = mine
        ? BorderRadius.only(
            topLeft: _radius,
            bottomLeft: _radius,
            topRight: top,
            bottomRight: bottom,
          )
        : BorderRadius.only(
            topRight: _radius,
            bottomRight: _radius,
            topLeft: top,
            bottomLeft: bottom,
          );

    final textColor = mine ? t.onBubbleOwn : t.textPrimary;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * _maxWidthShare,
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
      decoration: BoxDecoration(
        color: mine ? t.bubbleOwn : t.card,
        borderRadius: radius,
        border: mine ? null : Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (senderName != null && firstInGroup)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: t.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppTheme.spacing8,
            children: [
              Text(
                text,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: supported
                      ? textColor
                      : (mine ? t.onBubbleOwnSecondary : t.textSecondary),
                  fontStyle: supported ? null : FontStyle.italic,
                ),
              ),
              _Meta(message: message, mine: mine),
            ],
          ),
        ],
      ),
    );

    final failed = mine && message.status.isFailed;
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (senderName != null) ...[
          SizedBox(
            width: 32,
            child: lastInGroup
                ? AvatarInitials(name: senderName!, size: 32)
                : null,
          ),
          const SizedBox(width: AppTheme.spacing8),
        ],
        if (failed) _FailedButton(onTap: onFailedTap),
        Flexible(
          child: failed
              ? GestureDetector(onTap: onFailedTap, child: bubble)
              : bubble,
        ),
      ],
    );
  }
}

/// Time and, on the user's own messages, the delivery ticks.
class _Meta extends StatelessWidget {
  const _Meta({required this.message, required this.mine});

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    final l10n = AppLocalizations.of(context);
    final quiet = mine ? t.onBubbleOwnSecondary : t.textTertiary;

    final status = !mine
        ? null
        : switch (message.status) {
            MessageStatus.sending => (
                Icons.schedule_rounded,
                quiet,
                l10n.messageSending,
              ),
            MessageStatus.sent => (Icons.done_rounded, quiet, l10n.messageSent),
            MessageStatus.read => (
                Icons.done_all_rounded,
                t.accent,
                l10n.messageRead,
              ),
            // The red button beside the bubble says it.
            MessageStatus.failed => null,
          };

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormatter.time(message.createdAt.toLocal()),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: quiet,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTextTheme.tabular,
                ),
          ),
          if (status != null) ...[
            const SizedBox(width: 3),
            Icon(
              status.$1,
              size: 16,
              color: status.$2,
              semanticLabel: status.$3,
            ),
          ],
        ],
      ),
    );
  }
}

class _FailedButton extends StatelessWidget {
  const _FailedButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context).messageFailed,
      onPressed: onTap,
      icon: Icon(Icons.error_rounded, color: context.bfTheme.danger.fg),
    );
  }
}

/// «Сегодня», «Вчера» or a date over the first message of a day.
class DayDividerPill extends StatelessWidget {
  const DayDividerPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.bfTheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: ShapeDecoration(
          color: t.muted,
          shape: const StadiumBorder(),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: t.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

/// A system message: who joined or left the chat, centered and quiet.
class SystemMessageLine extends StatelessWidget {
  const SystemMessageLine({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.bfTheme.textTertiary,
            ),
      ),
    );
  }
}
