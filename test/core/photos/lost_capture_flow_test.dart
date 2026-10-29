import 'package:buildflow/app/routes.dart';
import 'package:buildflow/core/photos/lost_capture.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/core/widgets/photo_draft_tile.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_photo_compressor.dart';
import '../../helpers/fake_photo_picker.dart';
import '../../helpers/full_app.dart';

const _foreman = 'user-foreman-1';
const _lostShot = '/cache/image_picker_lost.jpg';

/// Android killed the app while the camera was open; on the next start the
/// shot goes back to the chat or the report it was taken for.
void main() {
  late FakePhotoPicker picker;
  late FakePhotoCompressor compressor;
  late LocalStorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    picker = FakePhotoPicker(lost: [_lostShot]);
    compressor = FakePhotoCompressor();
    storage = LocalStorageService();
  });

  /// Signs the foreman in, as the restored session would, then recovers
  /// the shot taken for [target].
  Future<FullApp> restart(WidgetTester tester, CaptureTarget target) async {
    final app = await FullApp.pump(
      tester,
      overrides: [
        photoPickerProvider.overrideWithValue(picker),
        photoCompressorProvider.overrideWithValue(compressor),
        localStorageProvider.overrideWithValue(storage),
      ],
    );
    await storage.saveJson(pendingCaptureKey, target.toJson());
    await app.login('foreman1@buildflow.kg');
    await app.container.read(lostCaptureProvider.notifier).recover();
    await app.settle();
    return app;
  }

  testWidgets('a shot for a chat opens the chat with it in the field',
      (tester) async {
    final app = await restart(
      tester,
      const CaptureTarget.chat(userId: _foreman, chatId: 'chat-project-1'),
    );

    expect(
      tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId,
      'chat-project-1',
    );
    expect(find.byType(PhotoDraftTile), findsOneWidget);
    expect(compressor.compressed, [_lostShot]);
    expect(app.container.read(lostCaptureProvider), isNull);
    await app.dispose();
  });

  testWidgets('a shot for a report opens the new report with its project',
      (tester) async {
    final app = await restart(
      tester,
      const CaptureTarget.report(userId: _foreman, projectId: 'project-2'),
    );

    expect(app.location, Routes.foremanNewReport);
    final report = find.byType(NewReportScreen);
    expect(
      find.descendant(of: report, matching: find.byType(PhotoDraftTile)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: report,
        matching: find.text('Коттеджный посёлок «Горный»'),
      ),
      findsOneWidget,
    );
    expect(compressor.compressed, [_lostShot]);
    await app.dispose();
  });

  testWidgets("someone else's shot is deleted, nothing opens", (tester) async {
    final app = await restart(
      tester,
      const CaptureTarget.chat(userId: 'user-owner-1', chatId: 'chat-project-1'),
    );

    expect(find.byType(ChatScreen), findsNothing);
    expect(app.location, Routes.foremanProjects);
    expect(compressor.deleted, [_lostShot]);
    expect(compressor.compressed, isEmpty);
    await app.dispose();
  });
}
