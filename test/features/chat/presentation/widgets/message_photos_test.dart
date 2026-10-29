import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/domain/entities/message_attachment.dart';
import 'package:buildflow/features/chat/presentation/widgets/message_photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

Message _photos(
  int count, {
  int width = 1600,
  int height = 1200,
  MessageStatus status = MessageStatus.sent,
}) =>
    Message(
      id: 'm-1',
      clientId: 'm-1',
      chatId: 'chat-1',
      senderId: 'user-foreman-1',
      kind: MessageKind.photo,
      createdAt: DateTime(2026, 10, 28, 11, 42),
      status: status,
      attachments: [
        for (var i = 0; i < count; i++)
          MessageAttachment(
            id: 'a$i',
            url: 'fake:p$i',
            width: width,
            height: height,
          ),
      ],
    );

void main() {
  final l10n = AppLocalizationsRu();

  test('grid rows: one alone, 2 side by side, 3 as 1 + 2, then 2 × 2', () {
    expect(photoGridRows(0), isEmpty);
    expect(photoGridRows(1), [1]);
    expect(photoGridRows(2), [2]);
    expect(photoGridRows(3), [1, 2]);
    expect(photoGridRows(4), [2, 2]);
    expect(photoGridRows(6), [2, 2]);
    expect(photoGridRows(10), [2, 2]);
  });

  Future<void> pumpPhotos(
    WidgetTester tester,
    Message message, {
    Map<String, double> progress = const {},
    ValueChanged<int>? onTap,
  }) =>
      pumpTestApp(
        tester,
        Scaffold(
          body: Center(
            child: MessagePhotos(
              message: message,
              width: 300,
              radius: BorderRadius.circular(14),
              uploadProgress: progress,
              onTap: onTap,
            ),
          ),
        ),
      );

  Size sizeOf(WidgetTester tester) =>
      tester.getSize(find.byType(MessagePhotos));

  testWidgets('one photo keeps its proportions', (tester) async {
    await pumpPhotos(tester, _photos(1));
    expect(find.byType(PhotoImage), findsOneWidget);
    expect(sizeOf(tester), const Size(300, 225));

    await pumpPhotos(tester, _photos(1, width: 1200, height: 1600));
    expect(sizeOf(tester), const Size(300, 400));

    // A panorama is limited, so it doesn't turn into a thin strip.
    await pumpPhotos(tester, _photos(1, width: 4000, height: 1000));
    expect(sizeOf(tester).height, closeTo(300 / 1.8, 0.01));
  });

  testWidgets('two photos stand side by side', (tester) async {
    await pumpPhotos(tester, _photos(2));
    expect(find.byType(PhotoImage), findsNWidgets(2));
    expect(sizeOf(tester), const Size(300, 149));
  });

  testWidgets('four photos make a 2 × 2 grid', (tester) async {
    await pumpPhotos(tester, _photos(4));
    expect(find.byType(PhotoImage), findsNWidgets(4));
    expect(sizeOf(tester), const Size(300, 149 * 2 + MessagePhotos.gap));
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('six photos show four, the last one with «+3»', (tester) async {
    int? tapped;
    await pumpPhotos(tester, _photos(6), onTap: (i) => tapped = i);
    expect(find.byType(PhotoImage), findsNWidgets(4));
    expect(find.text(l10n.morePhotos(3)), findsOneWidget);

    await tester.tap(find.text(l10n.morePhotos(3)));
    expect(tapped, 3);
  });

  testWidgets('a photo being sent shows its upload until done',
      (tester) async {
    await pumpPhotos(
      tester,
      _photos(2, status: MessageStatus.sending),
      progress: {'a0': 0.4, 'a1': 1},
    );
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.4);

    // Still compressing: a spinner without a value.
    await pumpPhotos(tester, _photos(1, status: MessageStatus.sending));
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );

    await pumpPhotos(tester, _photos(2), progress: {'a0': 0.4});
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
