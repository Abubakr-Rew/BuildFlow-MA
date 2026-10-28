import 'package:intl/intl.dart';

/// Date/time formatting utilities for Russian locale.
abstract final class DateFormatter {
  static final _dayMonth = DateFormat('d MMMM', 'ru');
  static final _dayMonthYear = DateFormat('d MMMM y', 'ru');
  static final _time = DateFormat('HH:mm', 'ru');
  static final _full = DateFormat('d MMMM y, HH:mm', 'ru');
  static final _weekday = DateFormat('E', 'ru');

  static String dayMonth(DateTime date) => _dayMonth.format(date);
  static String dayMonthYear(DateTime date) => _dayMonthYear.format(date);
  static String time(DateTime date) => _time.format(date);
  static String full(DateTime date) => _full.format(date);

  /// Returns 'Сегодня', 'Вчера', or a formatted date.
  static String relative(
    DateTime date, {
    required String today,
    required String yesterday,
  }) {
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (dateOnly == todayDate) return today;
    if (dateOnly == yesterdayDate) return yesterday;
    if (date.year == now.year) return dayMonth(date);
    return dayMonthYear(date);
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
    final current = now ?? DateTime.now();
    // Calendar days in UTC: a DST switch can't turn yesterday into today.
    final days = DateTime.utc(current.year, current.month, current.day)
        .difference(DateTime.utc(date.year, date.month, date.day))
        .inDays;
    final day = switch (days) {
      0 => today,
      1 => yesterday,
      >= 2 && <= 6 => _capitalized(_weekday.format(date)),
      _ when date.year == current.year => dayMonth(date),
      _ => dayMonthYear(date),
    };
    return '$day, ${time(date)}';
  }

  /// Time of a chat's last message in the chat list: «14:05» today,
  /// «Вчера», «Пн» within the last week, then «27 окт.»; «27.10.25» in
  /// another year.
  static String chatListTime(
    DateTime date, {
    required String yesterday,
    DateTime? now,
  }) {
    final local = date.toLocal();
    final current = now ?? DateTime.now();
    return switch (_daysBetween(local, current)) {
      <= 0 => time(local),
      1 => yesterday,
      >= 2 && <= 6 => _capitalized(_weekday.format(local)),
      _ when local.year == current.year => _dayShortMonth.format(local),
      _ => _numeric.format(local),
    };
  }

  /// Divider above the first message of a day: «Сегодня», «Вчера»,
  /// «27 октября»; the year only when it isn't the current one.
  static String chatDay(
    DateTime day, {
    required String today,
    required String yesterday,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    return switch (_daysBetween(day, current)) {
      <= 0 => today,
      1 => yesterday,
      _ when day.year == current.year => dayMonth(day),
      _ => dayMonthYear(day),
    };
  }

  static final _dayShortMonth = DateFormat('d MMM', 'ru');
  static final _numeric = DateFormat('dd.MM.yy', 'ru');

  /// Calendar days from [date] to [now], in UTC so that a DST switch can't
  /// turn yesterday into today.
  static int _daysBetween(DateTime date, DateTime now) =>
      DateTime.utc(now.year, now.month, now.day)
          .difference(DateTime.utc(date.year, date.month, date.day))
          .inDays;

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Groups a date to midnight for grouping reports by day.
  static DateTime toDateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
