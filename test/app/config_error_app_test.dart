import 'package:buildflow/app/config_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a misconfigured build says so instead of starting', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ConfigErrorApp(details: 'BACKEND=supabase needs SUPABASE_URL'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Сборка настроена неверно'), findsOneWidget);
    expect(find.text('BACKEND=supabase needs SUPABASE_URL'), findsOneWidget);
  });
}
