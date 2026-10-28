import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';

/// Messages of one author closer than this in time form a group: one name
/// above, one avatar below, tight spacing.
const messageGroupGap = Duration(minutes: 10);

/// A row of the chat: a day divider or a message.
sealed class TimelineItem {
  const TimelineItem();
}

/// «Сегодня», «Вчера» or a date above the first message of a day.
final class DayDivider extends TimelineItem {
  const DayDivider(this.day);

  /// Local midnight.
  final DateTime day;
}

final class MessageEntry extends TimelineItem {
  const MessageEntry(
    this.message, {
    required this.firstInGroup,
    required this.lastInGroup,
  });

  final Message message;
  final bool firstInGroup;
  final bool lastInGroup;
}

/// Rows for [messages] (oldest first): a [DayDivider] before each new
/// local day, and group flags for every message.
List<TimelineItem> buildTimeline(List<Message> messages) {
  final items = <TimelineItem>[];
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    final prev = i > 0 ? messages[i - 1] : null;
    final next = i + 1 < messages.length ? messages[i + 1] : null;
    if (prev == null || !_sameDay(prev.createdAt, m.createdAt)) {
      final local = m.createdAt.toLocal();
      items.add(DayDivider(DateTime(local.year, local.month, local.day)));
    }
    items.add(
      MessageEntry(
        m,
        firstInGroup: !_grouped(prev, m),
        lastInGroup: !_grouped(m, next),
      ),
    );
  }
  return items;
}

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

bool _grouped(Message? a, Message? b) =>
    a != null &&
    b != null &&
    a.kind != MessageKind.system &&
    b.kind != MessageKind.system &&
    a.senderId == b.senderId &&
    _sameDay(a.createdAt, b.createdAt) &&
    b.createdAt.difference(a.createdAt) <= messageGroupGap;
