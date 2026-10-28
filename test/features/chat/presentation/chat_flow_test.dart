import 'dart:async';

import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/app/routes.dart';
import 'package:buildflow/core/widgets/bf_bottom_nav.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/full_app.dart';

const _alaToo = 'ЖК «Ала-Тоо Резиденс»';

void main() {
  final l10n = AppLocalizationsRu();

  String openChatId(WidgetTester tester) =>
      tester.widget<ChatScreen>(find.byType(ChatScreen)).chatId;

  Finder navBadge(String count) => find.descendant(
        of: find.byType(BfBottomNav),
        matching: find.text(count),
      );

  testWidgets(
      'a foreman writes to the project chat; the director gets the badge '
      'and the message', (tester) async {
    final app = await FullApp.pump(tester);

    await app.login('owner@buildflow.kg');
    // Demo history: two unread in «Горный», one from Бакыт.
    expect(navBadge('3'), findsOneWidget);
    await app.logout();

    await app.login('foreman1@buildflow.kg');
    app.router.go(Routes.foremanChats);
    await app.settle();
    await tester.tap(find.text(_alaToo));
    await app.settle();
    expect(openChatId(tester), 'chat-project-1');

    await tester.enterText(find.byType(TextField), 'Залили 20 кубов');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip(l10n.sendMessage));
    await app.settle();
    expect(find.text('Залили 20 кубов'), findsOneWidget);

    await app.logout();
    await app.login('owner@buildflow.kg');
    expect(navBadge('4'), findsOneWidget);

    app.router.go(Routes.ownerChats);
    await app.settle();
    expect(find.text('Бакыт: Залили 20 кубов'), findsOneWidget);

    await tester.tap(find.text(_alaToo));
    await app.settle();
    expect(find.text('Залили 20 кубов'), findsOneWidget);
    expect(app.container.read(totalUnreadProvider), 3);

    await app.dispose();
  });

  testWidgets('«Написать» in the person sheet opens the direct chat',
      (tester) async {
    final app = await FullApp.pump(tester);
    await app.login('worker2@buildflow.kg');

    unawaited(app.router.push<void>(Routes.peopleSearch));
    await app.settle();
    await tester.enterText(find.byType(TextField), 'асан');
    await app.settle();
    await tester.tap(find.text('Асан Бекович'));
    await app.settle();
    await tester.tap(find.text(l10n.writeMessage));
    await app.settle();

    final chatId = FakeChatStore.directChatId(
      'user-worker-2',
      'user-owner-1',
    );
    expect(openChatId(tester), chatId);
    expect(find.text('Асан Бекович'), findsOneWidget);
    expect(find.text(l10n.chatNoMessages), findsOneWidget);

    // Opening it again reuses the chat.
    final chats = app.container.read(chatsProvider).valueOrNull!;
    expect(chats.where((c) => c.type.isDirect), hasLength(1));

    await app.dispose();
  });

  testWidgets('the project chat tile shows for the project team',
      (tester) async {
    final app = await FullApp.pump(tester);
    await app.login('worker1@buildflow.kg');
    unawaited(app.router.push<void>(Routes.project('project-1')));
    await app.settle();

    // Эрлан hasn't read the last two messages.
    final tile = find.ancestor(
      of: find.text(l10n.projectChat),
      matching: find.byType(InkWell),
    );
    expect(tile, findsWidgets);
    expect(
      find.descendant(of: tile.first, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.projectChat));
    await app.settle();
    expect(openChatId(tester), 'chat-project-1');

    await app.dispose();
  });
}
