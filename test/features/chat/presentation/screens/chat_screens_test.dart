import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/data/fake_chat_repository.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/providers/fake_chat_store_provider.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/test_app.dart';

const _owner = User(
  id: 'user-owner-1',
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

const _foreman = User(
  id: 'user-foreman-1',
  email: 'foreman1@buildflow.kg',
  name: 'Бакыт Касымов',
  role: UserRole.foreman,
  companyId: 'company-1',
);

const _alaToo = 'ЖК «Ала-Тоо Резиденс»';
const _gorny = 'Коттеджный посёлок «Горный»';

/// Fails the first [failures] sends, then sends normally.
class _FlakyChatRepository extends FakeChatRepository {
  _FlakyChatRepository({required super.store, required super.userId})
      : super(sendFailureRate: 0);

  int failures = 1;

  @override
  Future<Result<Message>> send(
    String chatId, {
    required String text,
    required String clientId,
  }) async {
    if (failures > 0) {
      failures--;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return const Err(Failure(FailureCode.network, message: 'offline'));
    }
    return super.send(chatId, text: text, clientId: clientId);
  }
}

void main() {
  final l10n = AppLocalizationsRu();

  FakeChatStore quietStore({bool demoHistory = true, DateTime Function()? now}) {
    final store = FakeChatStore(
      teamStore: FakeTeamStore(),
      projects: FakeProjectRepository.seed,
      demoHistory: demoHistory,
      now: now,
    );
    addTearDown(store.dispose);
    return store;
  }

  /// Fake latency: the stream, then the members.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  group('chat list', () {
    Future<void> pumpList(WidgetTester tester) async {
      await pumpTestApp(
        tester,
        const ChatListScreen(),
        overrides: [
          currentUserProvider.overrideWithValue(_owner),
          fakeChatStoreProvider.overrideWithValue(quietStore()),
        ],
      );
      await settle(tester);
    }

    testWidgets('shows project and direct chats with previews and unread',
        (tester) async {
      await pumpList(tester);
      expect(find.text(_alaToo), findsOneWidget);
      expect(find.text(_gorny), findsOneWidget);
      expect(find.text('Бакыт Касымов'), findsOneWidget);
      // «Имя: текст» in a project chat, just the text in a direct one.
      expect(
        find.text('Нурлан: Дорогу к участку размыло, грузовик не проходит. '
            'Нужен щебень.'),
        findsOneWidget,
      );
      expect(
        find.text('Заказчик доволен, просит ускорить фасад.'),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget); // «Горный»
      expect(find.text('1'), findsOneWidget); // Бакыт
    });

    testWidgets('chips filter by type, the field by project or name',
        (tester) async {
      await pumpList(tester);

      await tester.tap(find.text(l10n.chatFilterDirect));
      await tester.pump();
      expect(find.text('Бакыт Касымов'), findsOneWidget);
      expect(find.text(_alaToo), findsNothing);

      await tester.tap(find.text(l10n.chatFilterProjects));
      await tester.pump();
      expect(find.text('Бакыт Касымов'), findsNothing);
      expect(find.text(_alaToo), findsOneWidget);
      expect(find.text('Офис «Байтик»'), findsOneWidget);

      await tester.tap(find.text(l10n.chatFilterAll));
      await tester.enterText(find.byType(TextField), 'горн');
      await tester.pump();
      expect(find.text(_gorny), findsOneWidget);
      expect(find.text(_alaToo), findsNothing);
      expect(find.text('Бакыт Касымов'), findsNothing);

      await tester.enterText(find.byType(TextField), 'kasym');
      await tester.pump();
      expect(find.text('Бакыт Касымов'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'склад цемента');
      await tester.pump();
      expect(find.text(l10n.noChatsFound), findsOneWidget);
    });
  });

  group('chat screen', () {
    Future<void> pumpChat(
      WidgetTester tester, {
      required FakeChatStore store,
      User user = _foreman,
      String chatId = 'chat-project-1',
      List<Override> overrides = const [],
    }) async {
      await pumpTestApp(
        tester,
        ChatScreen(chatId: chatId),
        overrides: [
          currentUserProvider.overrideWithValue(user),
          fakeChatStoreProvider.overrideWithValue(store),
          ...overrides,
        ],
      );
      await settle(tester);
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      // The send button scales in, starting on the next frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('a sent message shows at once, then as sent', (tester) async {
      await pumpChat(tester, store: quietStore());
      expect(find.text(_alaToo), findsOneWidget);
      expect(find.text(l10n.chatParticipants(3)), findsOneWidget);

      // The send button shows up with the text.
      expect(find.byTooltip(l10n.sendMessage), findsNothing);
      await type(tester, '   ');
      expect(find.byTooltip(l10n.sendMessage), findsNothing);
      await type(tester, 'Опалубку сняли');
      await tester.tap(find.byTooltip(l10n.sendMessage));
      await tester.pump();

      expect(find.text('Опалубку сняли'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.text('Опалубку сняли'), findsOneWidget);
    });

    testWidgets('a failed message is retried from its menu', (tester) async {
      final store = quietStore();
      await pumpChat(
        tester,
        store: store,
        overrides: [
          chatRepositoryProvider.overrideWithValue(
            _FlakyChatRepository(store: store, userId: _foreman.id),
          ),
        ],
      );
      await type(tester, 'Нужен щебень');
      await tester.tap(find.byTooltip(l10n.sendMessage));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip(l10n.messageFailed), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.messageFailed));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.retry));
      await tester.pump();
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.byTooltip(l10n.messageFailed), findsNothing);
      expect(find.text('Нужен щебень'), findsOneWidget);
      expect(
        store.messagesFor('chat-project-1', _foreman.id).value.last.text,
        'Нужен щебень',
      );
    });

    testWidgets('day dividers: date, «Вчера», «Сегодня»', (tester) async {
      final now = DateTime.now();
      var clock = now.subtract(const Duration(days: 3));
      final store = quietStore(demoHistory: false, now: () => clock);
      void say(String text) => store.send(
            'chat-project-1',
            'user-owner-1',
            text: text,
            clientId: text,
          );
      say('Три дня назад');
      clock = now.subtract(const Duration(days: 1));
      say('Вчера вечером');
      clock = now;
      say('Сейчас');

      await pumpChat(tester, store: store);
      expect(
        find.text(DateFormatter.chatDay(
          now.subtract(const Duration(days: 3)),
          today: l10n.today,
          yesterday: l10n.yesterday,
        )),
        findsOneWidget,
      );
      expect(find.text(l10n.yesterday), findsOneWidget);
      expect(find.text(l10n.today), findsOneWidget);
      // Someone else's messages in a project chat carry the author.
      expect(find.text('Асан Бекович'), findsWidgets);
    });

    testWidgets('opening the chat reads it', (tester) async {
      final store = quietStore();
      expect(
        store
            .chatsFor(_owner.id)
            .value
            .firstWhere((c) => c.id == 'chat-project-2')
            .unreadCount,
        2,
      );
      await pumpChat(tester, store: store, user: _owner, chatId: 'chat-project-2');
      await tester.pump(const Duration(seconds: 1));
      expect(
        store
            .chatsFor(_owner.id)
            .value
            .firstWhere((c) => c.id == 'chat-project-2')
            .unreadCount,
        0,
      );
    });

    testWidgets('a removed member sees that the chat is unavailable',
        (tester) async {
      final store = quietStore();
      await pumpChat(tester, store: store);
      store.syncProject(
        FakeProjectRepository.seed.first.copyWith(foremanIds: []),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(l10n.chatUnavailable), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
