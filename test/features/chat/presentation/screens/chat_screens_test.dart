import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/audio/audio_providers.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/utils/date_formatter.dart';
import 'package:buildflow/core/widgets/photo_draft_tile.dart';
import 'package:buildflow/core/widgets/photo_thumbnail.dart';
import 'package:buildflow/core/widgets/photo_viewer.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/data/fake_chat_repository.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:buildflow/features/chat/presentation/providers/fake_chat_store_provider.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:buildflow/features/chat/presentation/widgets/message_photos.dart';
import 'package:buildflow/features/chat/presentation/widgets/voice_message.dart';
import 'package:buildflow/features/chat/presentation/widgets/voice_recorder_bar.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_photo_compressor.dart';
import '../../../../helpers/fake_voice.dart';
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
    required String clientId,
    String text = '',
    List<String> attachmentIds = const [],
  }) async {
    if (failures > 0) {
      failures--;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return const Err(Failure(FailureCode.network, message: 'offline'));
    }
    return super.send(
      chatId,
      text: text,
      clientId: clientId,
      attachmentIds: attachmentIds,
    );
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

    testWidgets('a photo message is previewed with an icon and its caption',
        (tester) async {
      await pumpList(tester);
      final preview = find.byWidgetPredicate(
        (w) =>
            w is RichText &&
            w.text.toPlainText().startsWith('Азамат: ') &&
            w.text.toPlainText().endsWith('2 фото · Леса вывезли'),
      );
      expect(preview, findsOneWidget);
      expect(
        find.descendant(
          of: preview,
          matching: find.byIcon(Icons.photo_camera_outlined),
        ),
        findsOneWidget,
      );
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

  group('photos in a chat', () {
    late FakePhotoCompressor compressor;

    Future<ProviderContainer> pumpChat(
      WidgetTester tester, {
      required FakeChatStore store,
      User user = _foreman,
      String chatId = 'chat-project-1',
    }) async {
      compressor = FakePhotoCompressor();
      await pumpTestApp(
        tester,
        ChatScreen(chatId: chatId),
        overrides: [
          currentUserProvider.overrideWithValue(user),
          fakeChatStoreProvider.overrideWithValue(store),
          photoCompressorProvider.overrideWithValue(compressor),
        ],
      );
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(ChatScreen)));
    }

    /// As if picked with «+»: the picker itself is the platform's.
    Future<void> pick(
      WidgetTester tester,
      ProviderContainer container,
      List<String> paths,
    ) async {
      container
          .read(photoDraftsProvider('chat:chat-project-1').notifier)
          .add(paths);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('picked photos go out as one message with the caption',
        (tester) async {
      final store = quietStore(demoHistory: false);
      final container = await pumpChat(tester, store: store);
      expect(find.byTooltip(l10n.attachPhoto), findsOneWidget);
      expect(find.byTooltip(l10n.takePhotoNow), findsOneWidget);

      await pick(tester, container, ['/c/1.jpg', '/c/2.jpg']);
      expect(find.byType(PhotoDraftTile), findsNWidgets(2));
      // Photos can go without a caption: the send button is there at once.
      expect(find.byTooltip(l10n.sendMessage), findsOneWidget);
      expect(find.text(l10n.photoCaptionHint), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Плита готова');
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.sendMessage));
      await tester.pump();

      expect(find.byType(PhotoDraftTile), findsNothing);
      expect(find.byType(MessagePhotos), findsOneWidget);
      expect(find.text('Плита готова'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // Two uploads of up to 1.4 s each, then the send's latency.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final sent = store.messagesFor('chat-project-1', _foreman.id).value.last;
      expect(sent.kind, MessageKind.photo);
      expect(sent.text, 'Плита готова');
      expect(sent.attachments.map((a) => a.url), [
        FakePhotoCompressor.copyOf('/c/1.jpg'),
        FakePhotoCompressor.copyOf('/c/2.jpg'),
      ]);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(compressor.deleted, ['/c/1.jpg', '/c/2.jpg']);
    });

    testWidgets('a photo that failed to compress holds the message',
        (tester) async {
      final store = quietStore(demoHistory: false);
      final container = await pumpChat(tester, store: store);
      compressor.failing.add('/c/bad.heic');
      await pick(tester, container, ['/c/bad.heic']);
      expect(find.bySemanticsLabel(l10n.photoProcessingFailed), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Подпись к фото');
      await tester.pump();
      await tester.tap(find.byTooltip(l10n.sendMessage));
      await tester.pump();
      expect(find.text(l10n.photoFailedBeforeSend), findsOneWidget);
      // Nothing is lost: the caption and the photo stay.
      expect(find.text('Подпись к фото'), findsOneWidget);
      expect(find.byType(PhotoDraftTile), findsOneWidget);

      compressor.failing.clear();
      await tester.tap(find.bySemanticsLabel(l10n.photoProcessingFailed));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.retry));
      // The sheet, titled the same as the mark, slides away meanwhile.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.bySemanticsLabel(l10n.photoProcessingFailed), findsNothing);
      expect(compressor.compressed, ['/c/bad.heic', '/c/bad.heic']);
      expect(store.messagesFor('chat-project-1', _foreman.id).value, isEmpty);
    });

    testWidgets('a photo opens the viewer on it, «+3» on the fourth',
        (tester) async {
      await pumpChat(
        tester,
        store: quietStore(),
        user: _owner,
        chatId: 'chat-project-2',
      );
      final grid = find.byType(MessagePhotos);
      expect(grid, findsOneWidget);
      final cells = find.descendant(of: grid, matching: find.byType(PhotoImage));
      expect(cells, findsNWidgets(4));

      await tester.ensureVisible(grid);
      await tester.tap(cells.at(1));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.text(l10n.photoOf(2, 6)), findsOneWidget);
      expect(
        find.text('Итоги дня: фундамент №4 и кладка №5'),
        findsWidgets,
      );
      expect(find.textContaining('${l10n.yesterday}, 17:40'), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.photoViewerClose));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.morePhotos(3)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.photoOf(4, 6)), findsOneWidget);
    });
  });

  group('recording a voice note', () {
    late FakeVoiceRecorder recorder;

    Future<FakeChatStore> pumpChat(WidgetTester tester) async {
      recorder = FakeVoiceRecorder();
      final store = quietStore(demoHistory: false);
      await pumpTestApp(
        tester,
        const ChatScreen(chatId: 'chat-project-1'),
        overrides: [
          currentUserProvider.overrideWithValue(_foreman),
          fakeChatStoreProvider.overrideWithValue(store),
          voiceRecorderProvider.overrideWithValue(recorder),
          voicePlayerProvider.overrideWithValue(FakeVoicePlayer()),
          photoCompressorProvider.overrideWithValue(FakePhotoCompressor()),
        ],
      );
      await settle(tester);
      return store;
    }

    Finder mic() => find.byType(VoiceMicButton);

    /// Presses the microphone and keeps the finger down for [seconds].
    Future<TestGesture> hold(WidgetTester tester, int seconds) async {
      final gesture = await tester.startGesture(tester.getCenter(mic()));
      await tester.pump();
      for (var i = 0; i < seconds * 10; i++) {
        recorder.emitLevel(0.5);
        await tester.pump(const Duration(milliseconds: 100));
      }
      return gesture;
    }

    testWidgets('the microphone shows while the field is empty',
        (tester) async {
      await pumpChat(tester);
      expect(mic(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Привет');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(mic(), findsNothing);
      expect(find.byTooltip(l10n.sendMessage), findsOneWidget);
    });

    testWidgets('hold, see the time and «Влево — отмена», lift: it is sent',
        (tester) async {
      final store = await pumpChat(tester);
      final gesture = await hold(tester, 2);
      expect(find.byType(VoiceHoldingBar), findsOneWidget);
      expect(find.text('0:02'), findsOneWidget);
      expect(find.text(l10n.voiceSlideToCancel), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await gesture.up();
      await tester.pump();
      expect(find.byType(VoiceHoldingBar), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      final sent = store.messagesFor('chat-project-1', _foreman.id).value.last;
      expect(sent.kind, MessageKind.voice);
      expect(sent.attachments.single.durationMs, 2000);
      expect(sent.attachments.single.waveform, hasLength(40));
    });

    testWidgets('a tap says «Удерживайте, чтобы записать»', (tester) async {
      await pumpChat(tester);
      await tester.tap(mic());
      await tester.pump();
      expect(find.text(l10n.voiceHoldToRecord), findsOneWidget);
    });

    testWidgets('a refused microphone says so, with «Настройки»',
        (tester) async {
      await pumpChat(tester);
      recorder.permitted = false;
      await tester.tap(mic());
      await tester.pump();
      expect(find.text(l10n.microphoneAccessDenied), findsOneWidget);
      expect(find.text(l10n.openSettings), findsOneWidget);
    });

    testWidgets('swipe up locks; stop gives a draft to listen and send',
        (tester) async {
      final store = await pumpChat(tester);
      final gesture = await hold(tester, 1);
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(VoiceLockedBar), findsOneWidget);
      expect(find.text('0:02'), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.voiceStop));
      await tester.pump();
      expect(find.byType(VoiceDraftBar), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(store.messagesFor('chat-project-1', _foreman.id).value, isEmpty);

      await tester.tap(find.byTooltip(l10n.sendMessage));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.byType(VoiceDraftBar), findsNothing);
      expect(
        store.messagesFor('chat-project-1', _foreman.id).value.single.kind,
        MessageKind.voice,
      );
    });

    testWidgets('swipe left cancels', (tester) async {
      final store = await pumpChat(tester);
      final gesture = await hold(tester, 2);
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();
      expect(find.byType(VoiceHoldingBar), findsNothing);
      await gesture.up();
      await tester.pump(const Duration(seconds: 2));
      expect(store.messagesFor('chat-project-1', _foreman.id).value, isEmpty);
      expect(recorder.calls.last, 'cancel');
    });
  });

  group('voice notes in the chat', () {
    late FakeVoicePlayer player;

    Future<FakeChatStore> pumpChat(WidgetTester tester) async {
      player = FakeVoicePlayer();
      final store = quietStore();
      await pumpTestApp(
        tester,
        const ChatScreen(chatId: 'chat-project-1'),
        overrides: [
          currentUserProvider.overrideWithValue(_owner),
          fakeChatStoreProvider.overrideWithValue(store),
          voicePlayerProvider.overrideWithValue(player),
          voiceRecorderProvider.overrideWithValue(FakeVoiceRecorder()),
        ],
      );
      await settle(tester);
      return store;
    }

    /// The demo note of [seconds] in «Ала-Тоо». By its length: a playing
    /// note shows its position instead.
    Finder note(int seconds) => find.byWidgetPredicate(
          (w) =>
              w is VoiceNotePlayer && w.duration == Duration(seconds: seconds),
        );

    Finder inNote(int seconds, Finder finder) =>
        find.descendant(of: note(seconds), matching: finder);

    testWidgets('an unplayed note has a dot until it is played',
        (tester) async {
      final store = await pumpChat(tester);
      await tester.ensureVisible(note(42));
      expect(inNote(42, find.bySemanticsLabel(l10n.voiceUnheard)),
          findsOneWidget);

      await tester.tap(inNote(42, find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();
      expect(player.calls.single, startsWith('play demo-voice:'));
      expect(inNote(42, find.bySemanticsLabel(l10n.voiceUnheard)),
          findsNothing);
      expect(inNote(42, find.byIcon(Icons.pause_rounded)),
          findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      final voice = store
          .messagesFor('chat-project-1', _owner.id)
          .value
          .lastWhere((m) => m.kind == MessageKind.voice);
      expect(voice.listened, isTrue);
    });

    testWidgets('the speed goes 1× → 1.5× → 2× while it plays',
        (tester) async {
      await pumpChat(tester);
      await tester.ensureVisible(note(42));
      expect(find.text(l10n.voiceSpeed('1')), findsNothing);
      await tester.tap(inNote(42, find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();

      await tester.tap(find.text(l10n.voiceSpeed('1')));
      await tester.pump();
      await tester.tap(find.text(l10n.voiceSpeed('1.5')));
      await tester.pump();
      expect(find.text(l10n.voiceSpeed('2')), findsOneWidget);
      expect(player.calls, contains('speed 2.0x'));
      // markListened's fake latency.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('one note plays at a time', (tester) async {
      await pumpChat(tester);
      await tester.ensureVisible(note(42));
      await tester.tap(inNote(42, find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();
      await tester.ensureVisible(note(7));
      await tester.tap(inNote(7, find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();

      expect(player.calls[1], 'stop');
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(inNote(7, find.byIcon(Icons.pause_rounded)),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('tapping the wave seeks there', (tester) async {
      await pumpChat(tester);
      await tester.ensureVisible(note(42));
      final wave = inNote(42, find.bySemanticsLabel(l10n.voiceMessage));
      final box = tester.getRect(wave);
      await tester.tapAt(Offset(box.left + box.width / 2, box.center.dy));
      await tester.pump();
      expect(player.calls.single, endsWith(' 21000'));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
