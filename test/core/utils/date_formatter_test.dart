import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
  });

  group('DateFormatter', () {
    test('toDateOnly strips time', () {
      final dt = DateTime(2024, 6, 15, 14, 30, 45);
      final dateOnly = DateFormatter.toDateOnly(dt);
      expect(dateOnly, DateTime(2024, 6, 15));
    });

    test('time formats HH:mm', () {
      final dt = DateTime(2024, 6, 15, 9, 5);
      final result = DateFormatter.time(dt);
      expect(result, '09:05');
    });

    test('relative returns today label', () {
      final today = DateFormatter.toDateOnly(DateTime.now());
      expect(
        DateFormatter.relative(today, today: 'Сегодня', yesterday: 'Вчера'),
        'Сегодня',
      );
    });

    test('relative returns yesterday label', () {
      final yesterday = DateFormatter.toDateOnly(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(
        DateFormatter.relative(yesterday, today: 'Сегодня', yesterday: 'Вчера'),
        'Вчера',
      );
    });

    test('relative returns formatted date for older dates', () {
      final oldDate = DateTime(2024, 3, 15);
      final result = DateFormatter.relative(
        oldDate,
        today: 'Сегодня',
        yesterday: 'Вчера',
      );
      // Returns "15 марта 2024" or "15 марта" depending on current year
      expect(result, isNotEmpty);
      expect(result, isNot('Сегодня'));
      expect(result, isNot('Вчера'));
    });
  });
  group('DateFormatter.reportDateTime', () {
    // Wednesday, 28 October 2026, 15:00.
    final now = DateTime(2026, 10, 28, 15);
    String format(DateTime date) => DateFormatter.reportDateTime(
      date,
      today: 'Сегодня',
      yesterday: 'Вчера',
      now: now,
    );

    test('today', () {
      expect(format(DateTime(2026, 10, 28, 11, 47)), 'Сегодня, 11:47');
      expect(format(DateTime(2026, 10, 28, 0, 5)), 'Сегодня, 00:05');
    });

    test('yesterday, even late at night', () {
      expect(format(DateTime(2026, 10, 27, 12, 47)), 'Вчера, 12:47');
      expect(format(DateTime(2026, 10, 27, 23, 59)), 'Вчера, 23:59');
    });

    test('within the week: capitalized short weekday', () {
      expect(format(DateTime(2026, 10, 26, 9, 30)), 'Пн, 09:30');
      expect(format(DateTime(2026, 10, 22, 8)), 'Чт, 08:00'); // 6 days ago
    });

    test('older this year: day and month', () {
      expect(format(DateTime(2026, 10, 21, 12, 47)), '21 октября, 12:47');
      expect(format(DateTime(2026, 1, 3, 7, 15)), '3 января, 07:15');
    });

    test('another year: with the year', () {
      expect(format(DateTime(2025, 10, 27, 12, 47)), '27 октября 2025, 12:47');
    });

    test('a week across the new year shows the weekday', () {
      final newYear = DateTime(2027, 1, 2, 10);
      expect(
        DateFormatter.reportDateTime(
          DateTime(2026, 12, 30, 18),
          today: 'Сегодня',
          yesterday: 'Вчера',
          now: newYear,
        ),
        'Ср, 18:00',
      );
    });
  });
}
