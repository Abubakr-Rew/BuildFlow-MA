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
        DateFormatter.relative(
          yesterday,
          today: 'Сегодня',
          yesterday: 'Вчера',
        ),
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
}
