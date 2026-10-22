import 'package:intl/intl.dart';

/// Date/time formatting utilities for Russian locale.
abstract final class DateFormatter {
  static final _dayMonth = DateFormat('d MMMM', 'ru');
  static final _dayMonthYear = DateFormat('d MMMM y', 'ru');
  static final _time = DateFormat('HH:mm', 'ru');
  static final _full = DateFormat('d MMMM y, HH:mm', 'ru');

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

  /// Groups a date to midnight for grouping reports by day.
  static DateTime toDateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
