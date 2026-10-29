import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/photos/lost_capture.dart';
import 'package:buildflow/core/photos/photo_picking.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_photo_compressor.dart';
import '../../helpers/fake_photo_picker.dart';

const _chat = CaptureTarget.chat(userId: 'u-1', chatId: 'chat-project-1');
const _report = CaptureTarget.report(userId: 'u-1', projectId: 'project-2');

void main() {
  late FakePhotoPicker picker;
  late FakePhotoCompressor compressor;
  late LocalStorageService storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    picker = FakePhotoPicker();
    compressor = FakePhotoCompressor();
    storage = LocalStorageService();
  });

  List<Override> overrides() => [
        photoPickerProvider.overrideWithValue(picker),
        photoCompressorProvider.overrideWithValue(compressor),
        localStorageProvider.overrideWithValue(storage),
      ];

  group('CaptureTarget', () {
    test('survives its JSON', () {
      for (final target in [
        _chat,
        _report,
        const CaptureTarget.report(userId: 'u-1'),
      ]) {
        expect(CaptureTarget.fromJson(target.toJson()), target);
      }
    });

    test('anything unreadable is null', () {
      for (final json in <Map<String, Object?>>[
        {},
        {'kind': 'voice', 'userId': 'u-1'},
        {'kind': 'chat', 'userId': 'u-1'},
        {'kind': 'report', 'userId': 1},
      ]) {
        expect(CaptureTarget.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('recover', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(overrides: overrides());
      addTearDown(container.dispose);
    });

    LostCaptureNotifier notifier() =>
        container.read(lostCaptureProvider.notifier);

    test('a lost shot comes back with the place it was taken for', () async {
      await storage.saveJson(pendingCaptureKey, _chat.toJson());
      picker.lost = ['/cache/image_picker123.jpg'];

      await notifier().recover();
      final capture = container.read(lostCaptureProvider)!;
      expect(capture.target, _chat);
      expect(capture.paths, ['/cache/image_picker123.jpg']);
      expect(await storage.readJson(pendingCaptureKey), isNull);
    });

    test('a shot without a saved place is deleted', () async {
      picker.lost = ['/cache/image_picker123.jpg'];
      await notifier().recover();
      expect(container.read(lostCaptureProvider), isNull);
      expect(compressor.deleted, ['/cache/image_picker123.jpg']);
    });

    test('nothing lost: the saved place is forgotten', () async {
      await storage.saveJson(pendingCaptureKey, _chat.toJson());
      await notifier().recover();
      expect(container.read(lostCaptureProvider), isNull);
      expect(await storage.readJson(pendingCaptureKey), isNull);
    });

    test('the right screen takes it once; discard deletes it', () async {
      await storage.saveJson(pendingCaptureKey, _report.toJson());
      picker.lost = ['/cache/a.jpg'];
      await notifier().recover();

      expect(notifier().take((t) => t.kind == CaptureKind.chat), isNull);
      expect(notifier().take((t) => t.kind == CaptureKind.report)?.paths, [
        '/cache/a.jpg',
      ]);
      expect(notifier().take((_) => true), isNull);

      await storage.saveJson(pendingCaptureKey, _report.toJson());
      picker.lost = ['/cache/b.jpg'];
      await notifier().recover();
      notifier().discard();
      expect(container.read(lostCaptureProvider), isNull);
      expect(compressor.deleted, ['/cache/b.jpg']);
    });
  });

  group('pickPhotos', () {
    final l10n = AppLocalizationsRu();

    /// A button that picks with [source] and keeps what came back.
    Future<List<String>> pick(WidgetTester tester, ImageSource source) async {
      var picked = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async => picked = await pickPhotos(
                    context,
                    ref,
                    source: source,
                    limit: 3,
                    target: _chat,
                  ),
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('keeps the place while the camera is open, then forgets it',
        (tester) async {
      Map<String, dynamic>? whileOpen;
      picker
        ..shot = '/cache/shot.jpg'
        ..whileCameraOpen = () async {
          whileOpen = await storage.readJson(pendingCaptureKey);
        };

      expect(await pick(tester, ImageSource.camera), ['/cache/shot.jpg']);
      expect(whileOpen, _chat.toJson());
      expect(await storage.readJson(pendingCaptureKey), isNull);
    });

    testWidgets('a refused camera says so, with «Настройки»', (tester) async {
      picker.cameraError = PlatformException(code: 'camera_access_denied');
      expect(await pick(tester, ImageSource.camera), isEmpty);
      expect(find.text(l10n.cameraAccessDenied), findsOneWidget);
      expect(find.text(l10n.openSettings), findsOneWidget);
      expect(await storage.readJson(pendingCaptureKey), isNull);
    });

    testWidgets('the gallery keeps no place and drops photos over the limit',
        (tester) async {
      picker.gallery = ['/a.jpg', '/b.jpg', '/c.jpg', '/d.jpg'];
      expect(await pick(tester, ImageSource.gallery), [
        '/a.jpg',
        '/b.jpg',
        '/c.jpg',
      ]);
      expect(picker.galleryLimits, [3]);
      expect(picker.cameraOpened, 0);
      expect(find.text(l10n.photoLimitReached(3)), findsOneWidget);
    });
  });
}
