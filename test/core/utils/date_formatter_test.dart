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

  group('chat dates', () {
    // Wednesday.
    final now = DateTime(2026, 10, 28, 15);

    String listTime(DateTime date) =>
        DateFormatter.chatListTime(date, yesterday: 'Вчера', now: now);

    String day(DateTime date) => DateFormatter.chatDay(
          date,
          today: 'Сегодня',
          yesterday: 'Вчера',
          now: now,
        );

    test('chat list: time today, «Вчера», weekday, then the date', () {
      expect(listTime(DateTime(2026, 10, 28, 9, 5)), '09:05');
      expect(listTime(DateTime(2026, 10, 27, 23, 59)), 'Вчера');
      expect(listTime(DateTime(2026, 10, 26, 8)), 'Пн');
      expect(listTime(DateTime(2026, 10, 22, 8)), 'Чт');
      expect(listTime(DateTime(2026, 10, 21, 8)), '21 окт.');
      expect(listTime(DateTime(2025, 10, 21, 8)), '21.10.25');
    });

    test('day dividers: «Сегодня», «Вчера», then the date', () {
      expect(day(DateTime(2026, 10, 28)), 'Сегодня');
      expect(day(DateTime(2026, 10, 27)), 'Вчера');
      expect(day(DateTime(2026, 10, 20)), '20 октября');
      expect(day(DateTime(2025, 12, 31)), '31 декабря 2025');
    });
  });

  group('time zones', () {
    tearDown(() => DateFormatter.debugUtcOffset = null);

    const bishkek = Duration(hours: 6);
    const newYork = Duration(hours: -5);

    DateTime utc(int day, int hour, [int minute = 0]) =>
        DateTime.utc(2026, 11, day, hour, minute);

    // Wednesday, 4 November, noon on the phone's clock.
    final noonBishkek = utc(4, 6);
    final noonNewYork = utc(4, 17);

    String report(DateTime at, DateTime now) => DateFormatter.reportDateTime(
          at,
          today: 'Сегодня',
          yesterday: 'Вчера',
          now: now,
        );

    test('a moment is shown on the phone clock', () {
      final at = utc(4, 5, 47);
      DateFormatter.debugUtcOffset = bishkek;
      expect(DateFormatter.time(at), '11:47');
      DateFormatter.debugUtcOffset = newYork;
      expect(DateFormatter.time(at), '00:47');
    });

    test("dates are the phone's dates", () {
      final at = utc(3, 20, 30);
      DateFormatter.debugUtcOffset = bishkek;
      expect(DateFormatter.dayMonth(at), '4 ноября');
      expect(DateFormatter.dayMonthYear(at), '4 ноября 2026');
      expect(DateFormatter.full(at), '4 ноября 2026, 02:30');
      DateFormatter.debugUtcOffset = newYork;
      expect(DateFormatter.dayMonth(at), '3 ноября');
      expect(DateFormatter.dayMonthYear(at), '3 ноября 2026');
      expect(DateFormatter.full(at), '3 ноября 2026, 15:30');
    });

    test('at +6 the hours 00:00–05:59 are already the new day', () {
      DateFormatter.debugUtcOffset = bishkek;
      expect(report(utc(3, 18), noonBishkek), 'Сегодня, 00:00');
      expect(report(utc(3, 23, 59), noonBishkek), 'Сегодня, 05:59');
      expect(report(utc(3, 17, 59), noonBishkek), 'Вчера, 23:59');
    });

    test('at -5 the same boundary is at 05:00 UTC', () {
      DateFormatter.debugUtcOffset = newYork;
      expect(report(utc(4, 5), noonNewYork), 'Сегодня, 00:00');
      expect(report(utc(4, 10, 59), noonNewYork), 'Сегодня, 05:59');
      expect(report(utc(4, 4, 59), noonNewYork), 'Вчера, 23:59');
      // Moments that are already «today» in Bishkek.
      expect(report(utc(3, 18), noonNewYork), 'Вчера, 13:00');
      expect(report(utc(3, 23, 59), noonNewYork), 'Вчера, 18:59');
    });

    test('the weekday is the local one', () {
      DateFormatter.debugUtcOffset = bishkek;
      expect(report(utc(1, 20), noonBishkek), 'Пн, 02:00');
      DateFormatter.debugUtcOffset = newYork;
      expect(report(utc(1, 20), noonNewYork), 'Вс, 15:00');
    });

    test('chat list time', () {
      String list(DateTime now) => DateFormatter.chatListTime(
            utc(3, 20, 30),
            yesterday: 'Вчера',
            now: now,
          );
      DateFormatter.debugUtcOffset = bishkek;
      expect(list(noonBishkek), '02:30');
      DateFormatter.debugUtcOffset = newYork;
      expect(list(noonNewYork), 'Вчера');
    });

    test('toDateOnly, relative and chatDay use the local day', () {
      final at = utc(3, 20, 30);
      String relative(DateTime now) => DateFormatter.relative(
            DateFormatter.toDateOnly(at),
            today: 'Сегодня',
            yesterday: 'Вчера',
            now: now,
          );
      String chatDay(DateTime now) => DateFormatter.chatDay(
            DateFormatter.toDateOnly(at),
            today: 'Сегодня',
            yesterday: 'Вчера',
            now: now,
          );

      DateFormatter.debugUtcOffset = bishkek;
      expect(DateFormatter.toDateOnly(at), DateTime(2026, 11, 4));
      expect(relative(noonBishkek), 'Сегодня');
      expect(chatDay(noonBishkek), 'Сегодня');

      DateFormatter.debugUtcOffset = newYork;
      expect(DateFormatter.toDateOnly(at), DateTime(2026, 11, 3));
      expect(relative(noonNewYork), 'Вчера');
      expect(chatDay(noonNewYork), 'Вчера');
    });

    test('an older day label keeps its own date', () {
      DateFormatter.debugUtcOffset = bishkek;
      expect(
        DateFormatter.relative(
          DateTime(2026, 11, 2),
          today: 'Сегодня',
          yesterday: 'Вчера',
          now: noonBishkek,
        ),
        '2 ноября',
      );
      expect(
        DateFormatter.chatDay(
          DateTime(2025, 12, 31),
          today: 'Сегодня',
          yesterday: 'Вчера',
          now: noonBishkek,
        ),
        '31 декабря 2025',
      );
    });

    test("isSameDay compares the phone's days", () {
      DateFormatter.debugUtcOffset = bishkek;
      expect(DateFormatter.isSameDay(utc(3, 17, 59), utc(3, 18)), isFalse);
      expect(DateFormatter.isSameDay(utc(3, 18), utc(4, 17, 59)), isTrue);
      DateFormatter.debugUtcOffset = newYork;
      expect(DateFormatter.isSameDay(utc(3, 17, 59), utc(3, 18)), isTrue);
      expect(DateFormatter.isSameDay(utc(4, 4, 59), utc(4, 5)), isFalse);
    });

    test('without the test offset it is the real time zone', () {
      final at = utc(4, 5, 47);
      final clock = at.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(DateFormatter.local(at), clock);
      expect(DateFormatter.time(at), '${two(clock.hour)}:${two(clock.minute)}');
    });

    test('a parsed server time shows the same however it was written', () {
      DateFormatter.debugUtcOffset = bishkek;
      for (final text in const [
        '2026-11-04T05:47:00Z',
        '2026-11-04T05:47:00.123456+00:00',
        '2026-11-04T11:47:00+06:00',
        '2026-11-04T00:47:00-05:00',
      ]) {
        final parsed = DateTime.parse(text);
        expect(parsed.isUtc, isTrue, reason: text);
        expect(DateFormatter.time(parsed), '11:47', reason: text);
      }
    });
  });
}
