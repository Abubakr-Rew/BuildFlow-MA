import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Date/time formatting utilities for Russian locale.
///
/// Entities keep their times in UTC, as moments. Everything here that takes
/// a moment shows it on the phone's clock, so screens never call `toLocal`.
/// A calendar day (from [toDateOnly]) isn't a moment: it goes to [relative]
/// and [chatDay] as is.
abstract final class DateFormatter {
  /// Stands in for the phone's time zone in tests, so any offset can be
  /// tried on any machine. A release build never reads it.
  @visibleForTesting
  static Duration? debugUtcOffset;

  /// [moment] on the phone's clock. Takes a moment, not an already local
  /// result: with [debugUtcOffset] a second call would shift it again.
  static DateTime local(DateTime moment) {
    if (kReleaseMode) return moment.toLocal();
    final offset = debugUtcOffset;
    return offset == null ? moment.toLocal() : moment.toUtc().add(offset);
  }

  /// Whether two moments fall on the same day of the phone's calendar.
  static bool isSameDay(DateTime a, DateTime b) {
    final x = local(a);
    final y = local(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  static final _dayMonth = DateFormat('d MMMM', 'ru');
  static final _dayMonthYear = DateFormat('d MMMM y', 'ru');
  static final _time = DateFormat('HH:mm', 'ru');
  static final _full = DateFormat('d MMMM y, HH:mm', 'ru');
  static final _weekday = DateFormat('E', 'ru');

  static String dayMonth(DateTime date) => _dayMonth.format(local(date));
  static String dayMonthYear(DateTime date) =>
      _dayMonthYear.format(local(date));
  static String time(DateTime date) => _time.format(local(date));

  /// Length of a voice note: «0:42», «4:59», «12:05».
  static String duration(Duration d) {
    final seconds = d.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  static String full(DateTime date) => _full.format(local(date));

  /// 'Сегодня', 'Вчера', or a formatted date for the calendar day [date].
  static String relative(
    DateTime date, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final current = local(now ?? DateTime.now());
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(current.year, current.month, current.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (dateOnly == todayDate) return today;
    if (dateOnly == yesterdayDate) return yesterday;
    if (date.year == current.year) return _dayMonth.format(date);
    return _dayMonthYear.format(date);
  }

  /// Report time relative to [now] (defaults to the current time):
  /// «Сегодня, 11:47», «Вчера, 12:47», «Пн, 09:30» within the last week,
  /// then «27 октября, 12:47»; the year only when it isn't the current one.
  static String reportDateTime(
    DateTime date, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final shown = local(date);
    final current = local(now ?? DateTime.now());
    final day = switch (_daysBetween(shown, current)) {
      0 => today,
      1 => yesterday,
      >= 2 && <= 6 => _capitalized(_weekday.format(shown)),
      _ when shown.year == current.year => _dayMonth.format(shown),
      _ => _dayMonthYear.format(shown),
    };
    return '$day, ${_time.format(shown)}';
  }

  /// Time of a chat's last message in the chat list: «14:05» today,
  /// «Вчера», «Пн» within the last week, then «27 окт.»; «27.10.25» in
  /// another year.
  static String chatListTime(
    DateTime date, {
    required String yesterday,
    DateTime? now,
  }) {
    final shown = local(date);
    final current = local(now ?? DateTime.now());
    return switch (_daysBetween(shown, current)) {
      <= 0 => _time.format(shown),
      1 => yesterday,
      >= 2 && <= 6 => _capitalized(_weekday.format(shown)),
      _ when shown.year == current.year => _dayShortMonth.format(shown),
      _ => _numeric.format(shown),
    };
  }

  /// Divider above the first message of the calendar day [day]: «Сегодня»,
  /// «Вчера», «27 октября»; the year only when it isn't the current one.
  static String chatDay(
    DateTime day, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final current = local(now ?? DateTime.now());
    return switch (_daysBetween(day, current)) {
      <= 0 => today,
      1 => yesterday,
      _ when day.year == current.year => _dayMonth.format(day),
      _ => _dayMonthYear.format(day),
    };
  }

  static final _dayShortMonth = DateFormat('d MMM', 'ru');
  static final _numeric = DateFormat('dd.MM.yy', 'ru');

  /// Calendar days between two dates on the phone's clock. They're compared
  /// as UTC dates so that a DST switch can't turn yesterday into today.
  static int _daysBetween(DateTime date, DateTime now) =>
      DateTime.utc(now.year, now.month, now.day)
          .difference(DateTime.utc(date.year, date.month, date.day))
          .inDays;

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// The calendar day of the moment [date] on the phone's clock, for
  /// grouping by day.
  static DateTime toDateOnly(DateTime date) {
    final shown = local(date);
    return DateTime(shown.year, shown.month, shown.day);
  }
}
