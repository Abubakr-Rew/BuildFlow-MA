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

  static String _capitalized(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Groups a date to midnight for grouping reports by day.
  static DateTime toDateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
