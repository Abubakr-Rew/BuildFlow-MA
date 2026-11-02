# BuildFlow — контекст для Claude

## О проекте
Flutter-приложение для ежедневных фото-отчётов со стройки для небольших строительных компаний Бишкека.
Прораб снимает объект и отправляет отчёт, владелец видит прогресс за день. Интерфейс только на русском.
Два режима сборки (`--dart-define=BACKEND`): `fake` — in-memory Fake-репозитории с демо-данными (по умолчанию в debug
и тестах), `supabase` — бэкенд на Supabase (`supabase/`, пока только локальный стек на компьютере, см. «Бэкенд»).
Основная цель — Android (тестируем на Xiaomi).

## Команды
```bash
flutter pub get                                           # зависимости
dart run build_runner build --delete-conflicting-outputs  # freezed / json_serializable
flutter gen-l10n                                          # после правки app_ru.arb
flutter run                                               # на подключённом устройстве, демо-данные
flutter run --dart-define-from-file=env/local.env         # с локальным Supabase (README: adb reverse, env)
flutter analyze                                           # цель: "No issues found!" (~2 мин)
flutter test                                              # все тесты
flutter test test/core/error/result_test.dart             # один файл
flutter test --plain-name "round-trip"                    # тесты по имени
flutter build apk --release                               # APK → build/app/outputs/flutter-apk/

# Бэкенд (нужны запущенный Docker Desktop и Node.js; CLI не ставится глобально)
npx supabase@2.122.0 start                                # локальный стек
npx supabase@2.122.0 db reset                             # миграции + seed.sql
npx supabase@2.122.0 test db                              # pgTAP
node supabase/tests/edge/smoke.mjs                        # Edge Functions, Storage, Realtime по HTTP
node tool/local_env.mjs                                   # env/local.env (URL и ключ, не в git) из supabase status
flutter test integration/supabase --dart-define-from-file=env/local.env  # клиент против стека (не в flutter test)
```

## Архитектура
**Стек:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, go_router 14, freezed 4 + json_serializable,
flutter_secure_storage, shared_preferences, image_picker, app_settings, intl, very_good_analysis,
record (запись голосовых), audioplayers (воспроизведение), supabase_flutter 2.18 (бэкенд), http (`ClientException`
сетевых ошибок, `MockClient` в тестах), dio (загрузка и скачивание файлов Storage с прогрессом).
Шрифт Inter лежит в `assets/fonts/inter/`, google_fonts не используется.
`app_settings` нужен только для того, чтобы открыть системные настройки приложения после отказа в разрешении.
`uuid` генерирует `clientId` сообщений чата.
Подключён, но в `lib/` не используется: cached_network_image (файлы Storage кэширует `RemoteFiles`). Сжатие фото — свой Kotlin-канал
(см. «Фото»), `flutter_image_compress` удалён.

```
lib/main.dart  конфигурация сборки (иначе ConfigErrorApp), ProviderContainer, тема до первого кадра,
               Supabase.initialize (только BACKEND=supabase), runApp
lib/app/       app.dart (MaterialApp.router), router.dart, routes.dart, theme/, l10n/
lib/core/      config.dart, error/ (Result, Failure), photos/ (сжатие, выбор, черновики фото), audio/ (голосовые),
               storage/ (secure, local, storage_providers), supabase/ (шлюз, ошибки, сессия, загрузки),
               remote_files/ (файлы Storage на телефоне), utils/, widgets/
android/app/src/main/kotlin/…/PhotoCompressor.kt   нативное сжатие фото (канал buildflow/photos)
android/app/src/main/kotlin/…/MainActivity.kt      каналы: buildflow/photos и buildflow/paths (cacheDir для записи)
lib/features/<фича>/data/          Fake*Repository, Supabase*Repository
                    domain/        entities/ (freezed), repositories/ (абстрактные интерфейсы)
                    presentation/  providers/, screens/, widgets/
```
Фичи: `auth`, `projects`, `reports`, `team`, `chat`, `profile` (у profile есть только `presentation/`).

**Ошибки — `Result<T>`** ([lib/core/error/result.dart](lib/core/error/result.dart)): sealed `Success(data)` / `Err(failure)`.
`Failure` ([failures.dart](lib/core/error/failures.dart)) — один класс. Что увидит пользователь, решает `code`
(enum `FailureCode`). `message` нужен только для логов и отладки и в UI не показывается. Есть ещё `statusCode`
и `stackTrace`. Коды: `network`, `timeout`, `server`, `invalidCredentials`, `emailTaken`, `invalidInviteCode`,
`sessionExpired`, `accountDisabled` (вход удалённого участника), `forbidden`, `notFound`, `validation`,
`tooManyRequests`, `photoProcessing` (только клиент: фото
не сжалось на устройстве), `unknown`. Соответствие HTTP-ответам — в docs/api-contract.md.
```dart
Future<Result<Project>> createProject(...);                                  // интерфейс репозитория
return Err(Failure(FailureCode.notFound, message: 'Project $id not found')); // ошибка
return Success(project);
result.when(success: (p) => ..., failure: (f) => ...);                       // у вызывающего
Text(l10n.failureMessage(error))                                             // в UI: Failure или любое исключение
```
Репозитории никогда не бросают исключений. В `AsyncNotifier.build()` Err превращается в `throw f`: `Failure`
реализует `Exception` и так попадает в `AsyncValue.error`.
Мутации нотифайеров возвращают `Future<Result<T>>` и не бросают исключений. `T` — созданный или обновлённый
объект (`Result<Project>`, `Result<Report>`, `Result<User>`), либо `void`, если вернуть нечего. Экран показывает
итог одним снэкбаром: `result.when(success: (_) => l10n.projectSaved, failure: l10n.failureMessage)`.
Общих текстов вроде «Не удалось выполнить действие» нет: причину всегда даёт `failureMessage`.
Текст ошибки в UI получать только через `l10n.failureMessage(error)` из
[failure_messages.dart](lib/app/l10n/failure_messages.dart), никогда через `failure.message` или `error.toString()`.
`AuthState.failure` показывается так же.

**Новый тип ошибки:**
1. Добавить значение в `FailureCode` (failures.dart) с doc-комментарием: когда возникает и какому HTTP-ответу соответствует.
2. Добавить ключ `error<Code>` в app_ru.arb (`FailureCode.emailTaken` → `errorEmailTaken`) и запустить `flutter gen-l10n`.
3. Добавить ветку в `switch` в failure_messages.dart. Switch исчерпывающий, без ветки код не скомпилируется.
4. Добавить строку в `expected` в test/app/l10n/failure_messages_test.dart, иначе упадёт тест на полноту.
5. Если код приходит от API — добавить строку в таблицу «Коды ошибок клиента» в docs/api-contract.md.

**Репозитории и DI:**
- Реализацию выбирает только `xxxRepositoryProvider` в `presentation/providers/<фича>_provider.dart`
  (`authRepositoryProvider` лежит в auth_provider.dart):
  `switch (kBackend) { Backend.fake => FakeXxxRepository(…), Backend.supabase => SupabaseXxxRepository(…) }`.
  `kBackend` / `kBackendConfig` — в [config.dart](lib/core/config.dart), из `--dart-define` `BACKEND`,
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`. Без `BACKEND` debug, profile и тесты — fake, release — `BackendConfigError`
  и экран `ConfigErrorApp` вместо приложения (демо-release — явный `BACKEND=fake`). `ProviderContainer` создаётся
  в main.dart без overrides и передаётся в `UncontrolledProviderScope`.
- Сервисы хранилищ создаются только в [storage_providers.dart](lib/core/storage/storage_providers.dart):
  `secureStorageProvider` и `localStorageProvider`. `FakeAuthRepository` получает `SecureStorageService` через
  `secureStorageProvider`. Напрямую `SecureStorageService()` / `LocalStorageService()` не создавать (кроме тестов).
- Новый репозиторий подключать так же: интерфейс в domain, `Fake*` и `Supabase*` в data, выбор в его провайдере.
  В тестах подменять через `ProviderScope(overrides: [xxxRepositoryProvider.overrideWithValue(...)])`.
- `Supabase*Repository` (все пять фич) ходят в бэкенд только через `SupabaseGateway`
  ([supabase_gateway.dart](lib/core/supabase/supabase_gateway.dart), `supabaseGatewayProvider`): `rpc(name, parse,
  params:)`, `invoke` (Edge Functions), `upload` (Dio, прогресс; повтор уже сохранённого файла — успех),
  `signUrls`, `download`. Ответы RPC разбирают готовые `fromJson` (`one()` / `listOf()` из core/supabase/json.dart).
  - Ошибки переводит `failureFromSupabase(error, call:)` ([supabase_failures.dart](lib/core/supabase/supabase_failures.dart)):
    PostgREST `PT<статус>` + `hint`, коды Auth, статус и `hint` Edge Functions, Storage, Dio, сеть. `SupabaseCall.signIn`
    (вход, регистрация, восстановление и их `get_me`): 403 `account_removed` → `accountDisabled`; `join`: 404 →
    `invalidInviteCode`; данные: 403 `account_removed` / `no_profile` → `sessionExpired`.
  - Запрос данных, обнаруживший конец сессии (`sessionExpired`), выходит на этом устройстве и сообщает в
    `gateway.sessionEnded`; туда же — выход, который сделал сам Auth (refresh-токен отозван, бан). `AuthRepository.sessionEnded`
    слушает `AuthNotifier`: `unauthenticated` с причиной, роутер ведёт на вход. Без сессии запрос данных не уходит.
  - Сессию хранит и обновляет supabase_flutter: `SecureSessionStorage` поверх `SecureStorageService` (с таймаутами),
    `AuthFlowType.implicit` (только пароль, без PKCE), `detectSessionInUri: false`. Просроченный токен клиент обновляет
    сам перед запросом. `SupabaseAuthRepository` кэширует последний профиль (`cachedProfileKey`) для старта без сети
    и шлёт в `join` `X-Device-Id` (uuid установки, `deviceIdKey`).
  - Вложения: `SupabaseUploads` (`create_upload` → Storage; тот же локальный файл второй раз не грузится, оборванная
    загрузка идёт в уже выданное вложение), своя загрузка сразу кладётся в кэш `RemoteFiles.adopt`.
  - `ProjectRepository.updateProject(id, ProjectChanges)` отправляет только изменённые поля (`null` — не менять).
  Контракт: [docs/api-contract.md](docs/api-contract.md), отличия Supabase — [docs/supabase-plan.md](docs/supabase-plan.md).
- Fake-репозитории изолированы друг от друга, но используют общие ID (`user-owner-1`, `user-foreman-1`, `project-1`…).
  Есть искусственная задержка. Данные живут только в памяти и при перезапуске сбрасываются.
  Исключение — участники и коды приглашения. Они лежат в общем
  [FakeTeamStore](lib/features/team/data/fake_team_store.dart) (in-memory «сервер» компании), который
  `fakeTeamStoreProvider` отдаёт и `FakeTeamRepository`, и `FakeAuthRepository`. Поэтому код, созданный директором,
  работает на экране присоединения, а новый участник появляется в команде. Провайдер лежит в отдельном
  `team/presentation/providers/fake_team_store_provider.dart`: его читает auth_provider, а team_provider уже импортирует
  auth_provider, так что в team_provider был бы цикл. Пользователи и пароли хранятся только в `FakeAuthRepository`.
  `FakeTeamStore.addMembersListener` сообщает об уходе и приходе участников, его слушает `FakeChatStore`.

**Фото** (`lib/core/photos/`, общее для отчётов и чата):
- `PhotoCompressor` (`photoCompressorProvider`) — `compress(sourcePath)` → `Result<CompressedPhoto>` (путь копии,
  размеры, байты, `takenAt`), `delete(paths)`, `sweep()`. Реализация `PlatformPhotoCompressor` — канал
  `buildflow/photos` к [PhotoCompressor.kt](android/app/src/main/kotlin/com/example/buildflow/PhotoCompressor.kt):
  декод с `inSampleSize`, поворот по EXIF в пиксели, масштаб длинной стороны до `kPhotoMaxSide` (1600) с фильтрацией,
  JPEG с качеством из `kPhotoQualitySteps` (82 → 74 → 66), пока не влезет в `kPhotoTargetBytes` (450 КБ), иначе
  последнее. `Bitmap.compress` не пишет EXIF: GPS, модель и серийники не уходят; назад читается только
  `DateTimeOriginal` + `OffsetTimeOriginal` (`parseExifDateTime`). Копии — в `cacheDir/photos`; `delete` и `sweep`
  трогают только `cacheDir`. Один фоновый поток. Любой сбой (HEIC до Android 9, битый файл, OOM, не Android) —
  `FailureCode.photoProcessing`, без исключений. В debug и profile в лог пишется «Photo compressed in 387 ms
  (work 169 ms): 3472×4624, 3207 KB → 1201×1600, 183 KB, quality 82» (work — без ожидания в очереди), в release — ничего.
  Для iOS реализации пока нет (нужна такая же на Swift).
- `pickPhotos(context, ref, source:, limit:, target:)` и `describePhotoPickError()` —
  [photo_picking.dart](lib/core/photos/photo_picking.dart): берёт оригиналы без ресайза через `PhotoPicker`
  (`photoPickerProvider`, обёртка над image_picker; галерея — `pickMultiImage(limit:)`, при `limit == 1` — `pickImage`),
  лишние сверх лимита отбрасывает со снэкбаром, при отказе в доступе — снэкбар с «Настройки».
- Потерянный кадр: Android может убить приложение, пока открыта камера. Поэтому `pickPhotos` на время камеры
  сохраняет `CaptureTarget` (чат или отчёт с объектом, и пользователь) в local storage (`pendingCaptureKey`).
  После первого кадра main.dart вызывает `lostCaptureProvider.notifier.recover()` → `retrieveLostData()`. Кадр
  с сохранённым местом ждёт в `lostCaptureProvider`, без места — удаляется. `_LostCaptureOpener` в оболочке роли
  (router.dart) открывает чат или новый отчёт (у прораба — вкладку), а экран забирает кадр `take(...)` в свои
  черновики и сжимает. Кадр другого пользователя удаляется.
- `photoDraftsProvider(scope)` (autoDispose family, `PhotoDraftsNotifier`) — выбранные фото одного места: `report:<uuid>`
  у каждого экрана нового отчёта, `chat:<id>` у поля ввода чата. Сжатие стартует сразу после выбора; `PhotoDraft` —
  `processing` / `ready` / `failed`. `retry`, `remove` (удаляет оригинал и копию), `takeAll()` (отдаёт фото с ещё
  идущим сжатием, например сообщению), `whenReady()` (ждёт все, для отчёта), `clear()` (после отправки: удаляет
  только оригиналы). Уход с места удаляет файлы оставшихся фото.
- Жизнь файлов: оригинал из кэша image_picker живёт, пока фото не отправлено или не убрано (из него повторяют
  сжатие и показывают превью); сжатая копия после отправки — это и есть фото (в Fake её путь служит URL).
  При запуске после первого кадра `sweep()` удаляет копии и остатки image_picker старше суток.
- `PhotoImage` декодирует локальные файлы под размер на экране (`cacheWidth`), а не все 12 Мп оригинала.
- Файлы сервера: `url` вложения — `storage:<bucket>/<path>` (`StorageRef`, сущности читают его из `bucket` и `path`
  через `@JsonKey(readValue: readStorageUrl)`). [RemoteFiles](lib/core/remote_files/remote_files.dart)
  (`remoteFilesProvider`) подписывает ссылки на час (кэш по attachmentId, заново за 5 мин до конца или если
  скачивание отказано; ссылки одного экрана — одним запросом на бакет) и скачивает в `cacheDir/remote/<attachmentId>.<ext>`.
  `PhotoImage` и голосовые (`VoicePlaybackNotifier`) берут файл оттуда. `clear()` — при выходе, конце сессии
  и каждом входе; `sweep()` после старта (30 дней, 300 МБ).

**Голосовые** (`lib/core/audio/` + чат):
- `VoiceRecorder` (`voiceRecorderProvider`, поверх record): AAC-LC в M4A, моно, `kVoiceBitRate` 32 кбит/с,
  `kVoiceSampleRate` 22 050 Гц, файл `cacheDir/voice-<uuid>.m4a`; громкость каждые 100 мс (`levelFromDbfs`);
  звонок ставит запись на паузу (по умолчанию в record), это приходит в `interruptions()`.
- `VoicePlayer` (`voicePlayerProvider`, поверх audioplayers) и `voicePlaybackProvider`: одно голосовое на всё
  приложение, пауза помнит место, `seek`, скорость 1× / 1.5× / 2× на сессию. Звонок забирает аудиофокус:
  audioplayers ставит голосовое на паузу и после звонка продолжает с того же места.
- `downsampleWaveform` — 40 полос 0–100 (самая громкая = 100). `DemoVoice` — демо-голосовые, сгенерированные
  в коде (`demo-voice:<seed>:<ms>`, WAV 8 кГц играется из байтов), в репозитории аудиофайлов нет.
- Запись — машина состояний `VoiceRecordingNotifier` (`voiceRecordingProvider(chatId)` в chat):
  `idle → starting → holding → locked → draft`. Удержание микрофона пишет, отпускание отправляет (меньше
  `kVoiceMinDuration` 1 с — подсказка «Удерживайте, чтобы записать»), свайп влево на `voiceCancelDistance` отменяет,
  вверх на `voiceLockDistance` — замок («Удалить» / стоп / «Отправить»). Стоп, `kVoiceMaxDuration` (5 мин) и звонок
  переводят в черновик («Удалить», «Прослушать», «Отправить») с короткой вибрацией — сами ничего не отправляют.
  Разрешение — при первом нажатии; если палец отпустили ради системного диалога, запись не начинается. Запись
  останавливает играющее голосовое; уход из чата удаляет запись и черновик. Подсказки (`VoiceHint`) приходят
  разовыми: `hintSeq` растёт.
- Кнопка микрофона (`VoiceMicButton`, `Listener` с координатами от точки нажатия) стоит в `trailingWhenEmpty`;
  на время записи `ChatComposer.replacement` заменяет «+» и поле (`VoiceHoldingBar` / `VoiceLockedBar` /
  `VoiceDraftBar`), а `showTrailing` оставляет удерживаемый микрофон. Хвостовая кнопка в композере с ключом,
  иначе при смене строки микрофон потерял бы палец.
- Пузырь — `VoiceNotePlayer` (voice_message.dart): акцентная play/pause, `VoiceWaveform` с перемоткой, время
  (длина или позиция), скорость пока играет, точка у чужого непрослушанного, кольцо загрузки при отправке.

**Чат** (`lib/features/chat/`, этапы 1–3 из 4: основа, текст, фото, голосовые; дальше карточки отчётов и пуши):
- Сущности `Chat` (`direct` | `project`) и `Message` (`kind`: `text`, `photo`, `voice`, `report`, `system`).
  `photo` — до `maxPhotosPerMessage` (10) вложений в `attachments` (`url`, `width`, `height`), `text` — подпись.
  `voice` — одно вложение (`durationMs`, `waveform`, `mime`), без текста; `Message.listened` — прослушал ли
  текущий пользователь чужое голосовое. `reportId` — задел на этап 4. Чего клиент не умеет показать
  (`!kind.isSupported`), то рисуется пузырём «Неподдерживаемое сообщение».
- `ChatRepository` — потоки `watchChats()` / `watchMessages(chatId)` (последние `chatPageSize` = 50) и `Result`-методы
  `loadOlder`, `uploadPhoto(CompressedPhoto, onProgress:)` / `uploadVoice(VoiceNote, onProgress:)` → вложение,
  `send(text:, attachmentIds:)` (идемпотентно по `clientId`), `getOrCreateDirect`, `markRead`, `markListened`. Потоки не бросают: отказ —
  событие ошибки с `Failure` (`forbidden`, когда пользователя исключили), оно попадает в `AsyncValue.error`.
- [SupabaseChatRepository](lib/features/chat/data/supabase_chat_repository.dart): `get_chats` и последняя страница
  `get_messages`, дальше события приватного канала Realtime `user:<id>` (`ChatEvents` / `SupabaseChatEvents` в
  chat_events.dart): `message.created` (без дублей), `message.status` (свои до `upTo` — `read`), `chat.updated`,
  `chat.removed` (поток открытого чата — ошибка `forbidden`). Пропущенное догружается (`catchUp`: `get_chats` и
  `get_messages(after:)` открытых чатов, при `truncated` — последняя страница заново), когда канал снова вошёл и когда
  приложение вернулось из фона (`onAppResumed` через `AppLifecycleListener`: упавший канал сначала переподключается).
  Вид сообщения для `send_message` репозиторий знает по своим загрузкам. Репозиторий привязан к пользователю:
  выход и смена пользователя закрывают его канал. Канал открывает `chatEventsFactoryProvider` (в тестах —
  `FakeChatEvents`); провайдерный тест подставляет `chatRepositoryProvider.overrideWith(supabaseChatRepository)`.
- [FakeChatStore](lib/features/chat/data/fake_chat_store.dart) — общий in-memory «сервер» всех пользователей
  процесса (broadcast `StreamController`), поэтому после выхода и входа другим человеком сообщения на месте.
  Отдаёт его `fakeChatStoreProvider` из отдельного файла (его читает project_provider, а chat_provider импортирует
  team_provider → project_provider). `FakeChatRepository` — тонкая обёртка с задержкой и `userId` текущего пользователя.
  - Состав чата объекта = директора компании + `foremanIds` + `workerIds`. `FakeProjectRepository(onProjectChanged:)`
    вызывает `FakeChatStore.syncProject` после create/update. Кто пришёл или ушёл — системное сообщение.
  - Удалённый из компании теряет все чаты компании, включая личные (через `FakeTeamStore`); его личные чаты
    остаются у собеседника только для чтения.
  - Демо-история: чаты объектов 1–4 (в «Ала-Тоо» 66 сообщений, чтобы листать страницы), личные директор ↔ Бакыт
    и Бакыт ↔ Эрлан. У директора на старте 3 непрочитанных. Id личного чата — `FakeChatStore.directChatId(a, b)`.
  - Фото: `FakeChatRepository.uploadPhoto` отчитывается о прогрессе 10 шагами около секунды, путь сжатой копии
    становится URL. `FakeChatStore.registerUpload` + `send(attachmentIds:)`: прикрепить вложение может только
    загрузивший и только один раз, иначе `forbidden`; голосовое — одно и без текста, иначе `validation`. «Прослушано»
    хранится по пользователям. В демо-истории есть сообщения с 1, 2, 3 и 6 фото (`fake:`) и три голосовых
    (0:07 и 0:42 в «Ала-Тоо», 0:23 в личном директор ↔ Бакыт).
  - Флаги в config.dart (только при `Backend.fake`): `kFakeChatEcho` — собеседник в личном чате «читает» через 1–2 с
    и отвечает через 2–4 с; `kFakeChatSendFailureRate` (0–1) — доля отправок и загрузок фото с ошибкой `network`
    (загрузка обрывается на середине), для ручной проверки «Повторить / Удалить».
- Провайдеры в chat_provider.dart: `chatsProvider` (`StreamNotifierProvider`, сырые чаты), `chatListProvider`
  (с именами собеседников, loading до загрузки участников), `chatByIdProvider`, `projectChatProvider(projectId)`,
  `totalUnreadProvider` (бейдж вкладки), `memberNamesProvider`, `chatThreadProvider(chatId)` (autoDispose family).
  `ChatThreadNotifier` держит все виденные сообщения по id (сообщение, выпавшее из живой страницы, не пропадает)
  и очередь своих `sending`/`failed` по `clientId`; `send` / `sendPhotos` / `retry` / `discard` / `loadOlder` / `markRead`.
  Повтор идёт с тем же `clientId`. `markRead` шлёт отметку, только если последнее сообщение чужое и ещё не отмечено.
  `sendPhotos(takeAll(), caption:)`: сообщение сразу «отправляется» с оригиналами, ждёт сжатие, грузит фото по
  одному (`ChatThread.uploadProgress` по id вложения), потом `send`. Сбой сжатия или загрузки — `failed`; повтор
  сжимает заново только упавшее и не грузит уже загруженные. `discard` удаляет файлы, успех — только оригиналы.
  `sendVoice(note)` идёт той же очередью (прогресс под `clientId`, повтор без повторной загрузки).
  `markListened(message)` сразу гасит точку и шлёт отметку на сервер.
- Экран чата — `CustomScrollView(reverse: true, center: история)`: история растёт вверх, сообщения, пришедшие, пока
  человек читает выше, — в отдельный sliver ниже центра, поэтому не сдвигают текст; вместо этого плашка
  «Новые сообщения ↓». Своё сообщение или новое, когда пользователь внизу, переносит якорь и прыгает вниз.
  Ленту строит чистая `buildTimeline()` (chat_timeline.dart): разделители дней, группы одного автора (пауза ≤ 10 мин).
- Поле ввода `ChatComposer`: `leading` («+» → «Камера / Галерея», галерея до 10), `fieldSuffix` (камера в поле), `top`
  (полоса `PhotoDraftTile` выбранных фото), `hasAttachments` (кнопка отправки без текста, подсказка «Подпись»),
  `trailingWhenEmpty` (микрофон), `replacement` / `showTrailing` (запись). `onSend` возвращает `bool`: поле очищается, только если ушло, поэтому
  при фото с ошибкой сжатия подпись остаётся, а снэкбар просит повторить или убрать фото.
- Фото в ленте — `MessagePhotos` (message_photos.dart): раскладка `photoGridRows()` — 1 по пропорциям (0.6–1.8),
  2 рядом, 3 как 1 + 2, от 4 — 2 × 2 и «+N» на последней ячейке. Подпись под фото в пузыре; без подписи время
  и галочки на графитовой плашке поверх фото. Нажатие открывает `PhotoViewer` на этом фото (Hero —
  `chatPhotoHeroTag`). В списке чатов — «Фото» / «3 фото · подпись» с иконкой камеры (`chatPreview` отдаёт
  `prefix`, `text`, `media`). Голосовое в списке — «Голосовое · 0:42» с иконкой микрофона.
- Поиск по чатам — `searchChats()` (chat_search.dart) по правилам `matchName`, кавычки и знаки читаются как пробелы.
- Тексты (превью «Бакыт: …», «Вы: …», системные, «Бывший сотрудник») — расширение `ChatTexts` на `AppLocalizations`.
- Входы: вкладка «Чаты», плитка «Чат объекта» с бейджем на карточке объекта (видна, если пользователь в команде),
  «Написать» в шите человека в поиске людей. Себе написать нельзя.

**Роли:** `UserRole { owner, foreman, worker }` ([user_role.dart](lib/features/auth/domain/entities/user_role.dart)).
UI-хелперы — `label(l10n)`, `icon`, `color`, `RoleBadge` — в [role_label.dart](lib/features/auth/presentation/role_label.dart).
- [router.dart](lib/app/router.dart): по одному `StatefulShellRoute` (`_shell`) на роль, у каждой своя нижняя навигация
  (`_RoleShell`). Owner: объекты, команда, чаты, отчёты, профиль. Foreman: объекты, чаты, «Отчёт» (акцентная
  кнопка с камерой в центре, `BfNavItem.prominent`, новый отчёт), «История» (список отчётов), профиль.
  Worker: объекты, чаты, отчёты, профиль. На вкладке «Чаты» бейдж — `totalUnreadProvider`.
- Пути — в [routes.dart](lib/app/routes.dart): `/owner/*`, `/foreman/*`, `/worker/*`, плюс `Routes.homeFor(role)`,
  `chatsFor(role)` и `prefixFor(role)`.
- Навигацию по авторизации делает только роутер. Чистая функция `authRedirect(AuthState, path)` в router.dart:
  статус `initial` → остаёмся на сплэше; нет пользователя → `/login`; сплэш, login, register или join → home роли;
  префикс чужой роли → home роли. Тесты лежат в `test/app/router_test.dart`.
- `routerProvider` создаёт `GoRouter` один раз. `refreshListenable` срабатывает, когда в `authProvider` меняется
  `(status, user)`. После login, register, join, logout и restoreSession **не вызывать `context.go`**: достаточно сменить
  состояние в `AuthNotifier`.
- `/projects/:id`, `/reports/:id`, `/chats/:id` и `/people` (поиск людей) — роуты верхнего уровня вне shell, поэтому
  открываются поверх навигации. Открывать через `context.push(Routes.project(id))` / `Routes.report(id)` /
  `Routes.chat(id)` / `Routes.peopleSearch`.
- Поиск людей ([people_search_screen.dart](lib/features/team/presentation/screens/people_search_screen.dart)).
  Вход — `BfIconButton(Icons.person_search_rounded)` в шапке: у директора на вкладке «Команда», у прораба
  и строителя на списке объектов (своей вкладки команды у них нет). Если на список объектов добавят поиск
  объектов, у него будет лупа, а не `person_search`.
  - Сопоставление — чистые `matchName()` / `searchMembers()` в
    [member_search.dart](lib/features/team/domain/member_search.dart). Правила:
    - начало любого слова, регистр не важен;
    - ё = е, ң/ө/ү = н/о/у;
    - латиница читается как кириллица, й/ы/и и э/е склеиваются.

    Свёртка имени посимвольная: диапазоны совпадений сразу ложатся на исходную строку и идут в подсветку.
    Те же правила записаны для сервера в api-contract.md (`GET /team/members?query=&role=`).
  - Ищет на клиенте по `membersProvider`, себя не показывает. Запрос короче `minPeopleSearchLength` (2) без
    выбранной роли показывает «Недавние»: `recentPeopleProvider`, до 5 id, только в памяти, сбрасывается
    при смене пользователя.
  - Объекты человека — `memberProjectsProvider(userId)` по `Project.foremanIds/workerIds` из видимых
    объектов. Прораб и строитель видят только общие объекты. `Member.assignedProjectIds` не обновляется
    при смене состава, на него не опираться.
- Фото отчёта: `ReportRepository.submitReport(photos: List<CompressedPhoto>)`, `NewReportScreen` ждёт сжатие
  (`whenReady`) и не отправляет отчёт с несжатым фото. `ReportPhoto.takenAt` — время съёмки из EXIF;
  `takenOnAnotherDay()` (reports/domain/photo_capture.dart) — снято в другой день, чем отправлен отчёт; в просмотрщике
  «Снято 11:42» и бейдж «Снято не сегодня». GPS не извлекается и не хранится.
- Видимость данных по ролям — в провайдерах, а не в роутере: `canSeeProject()` в project_provider.dart.
  `reportsProvider` отдаёт отчёты только по видимым объектам.
  Обложка шапки объекта — `projectCoverProvider` (последнее фото последнего отчёта с фото); без фото шапка
  180 px на графите, с фото 250 px под затемнением `BuildFlowThemeExtension.coverScrimOpacity`.
  Сводка дня на экране объектов (`daySummaryProvider`, `todayReportTimeProvider`) лежит в report_provider.dart
  и считается по видимым объектам. Пока отчёты не загрузились, сводка в состоянии loading: иначе все объекты
  на мгновение выглядели бы «без отчёта».
- `Project.progress` — готовность 0–100. Меняет только директор из меню «ещё» на карточке объекта (шаг 5 %,
  `ProjectsNotifier.setProgress`). Смена статуса и готовности блокирует друг друга и редактор состава.

## Бэкенд (Supabase)
Подробно — [docs/supabase-plan.md](docs/supabase-plan.md): решения, схема, соответствие эндпоинтов функциям, клиент,
что сделать перед пилотом. Только локально: приложение ходит в стек на компьютере (`BACKEND=supabase`, README).
- `supabase/migrations/` — по файлу на этап. Уже закоммиченную миграцию не править, а писать новую
  (`create or replace`, `drop trigger` …): после `db push` в облако старые миграции не перезапускаются.
- Чтение — RPC `get_*` с правами вызывающего под RLS. Запись — только RPC с `security definer`, которые сами
  проверяют роль: у `authenticated` на таблицах только `SELECT`. Первая строка каждой клиентской функции —
  `private.require_user()` (401 без сессии, 403 `no_profile` / `account_removed`) или `require_owner()`.
- Новая функция: `revoke execute … from public, anon` и `grant … to authenticated` (клиентская) или
  `to service_role` (для Edge Functions, первая строка — `private.require_service()`), плюс строка в
  `client_functions` / `service_functions` в `supabase/tests/database/010_privileges.sql`, иначе тест упадёт.
- Хелперы, триггеры и служебные таблицы — в схеме `private` (не публикуется). Ошибки — `private.fail(404, 'not_found')`
  → HTTP 404 с машинным `hint`.
- Права никогда не берутся из `user_metadata`: роль и компания — только из `profiles`. Триггер регистрации читает
  `name`, `company_name` и `invite_code` (последний — из `app_metadata`, её ставит только Edge Function `join`).
- В `auth.users` и `auth.sessions` SQL не пишет: бан и выход — admin API в Edge Function `remove-member`.
- Подводные камни: триггер регистрации отложен до `COMMIT` (`admin.createUser` дописывает `app_metadata` вторым
  запросом); `on_message_notify` (`message.created`) тоже отложен до `COMMIT`, иначе событие уходит без вложений:
  `send_message` прикрепляет их после вставки сообщения. pgTAP не делает `COMMIT`: `tests.create_user` оставляет
  ограничения `immediate`, а проверке «событие после коммита» нужны `set constraints all deferred` до и `immediate`
  после (070_realtime). У отчётов и сообщений одной транзакции одинаковый `now()`, в тестах порядок задавать явно;
  `stable`-функция в том же `select`, что и мутация, видит снимок до неё.
- Лимит `join` — 10 в минуту с IP: смоук-тест его выбирает, интеграционный тест после него ждёт минуту (иначе 429).

## Соглашения
- Файлы в snake_case. Классы: `XxxScreen`, `XxxRepository` (интерфейс), `FakeXxxRepository` / `SupabaseXxxRepository`,
  `XxxNotifier`, `xxxProvider`. Приватные виджеты `_Xxx` лежат в том же файле. Разделители секций: `// ── Title ───`.
- Импорты только абсолютные: `package:buildflow/...`.
- Сущности: `@freezed abstract class X with _$X` + `factory X.fromJson`, `part 'x.freezed.dart'; part 'x.g.dart';`.
  Перечисления — обычные Dart enum с геттерами (`status.isActive`, `role.isOwner`).
- Провайдеры — top-level `final` в `presentation/providers/<фича>_provider.dart`, не в файлах экранов и виджетов.
  Провайдеры core-сервисов — в `lib/core/<модуль>/`, `routerProvider` — в router.dart:
  - список: `AsyncNotifierProvider<XxxNotifier, List<X>>`; в `build()` вызывать `ref.watch(currentUserProvider)`
    (из auth_provider.dart), чтобы список перезагружался при смене пользователя;
  - живой список с сервера (сейчас только чаты): `StreamNotifierProvider`, `build()` возвращает поток репозитория;
    мутации после успеха не инвалидируют его — изменение приходит потоком;
  - один элемент: `Provider.family<AsyncValue<X?>, String>`, выводится из списка (`projectByIdProvider`, `reportByIdProvider`);
  - после успешной мутации вызывать `ref.invalidateSelf()`.
  - синхронное состояние: `NotifierProvider` — `authProvider` (`AuthNotifier`; `AuthState` сам хранит статус,
    загрузку и ошибку) и `themeModeProvider` в profile_provider.dart (его читает app.dart). Тема сохраняется
    через `localStorageProvider` (ключ `theme_mode`), `restore()` вызывается в main.dart до `runApp`.
  - Legacy `StateProvider` / `StateNotifierProvider` не использовать.
- Экраны: `ConsumerWidget`; если есть форма или контроллеры — `ConsumerStatefulWidget`. Каркас зависит от места:
  - вкладка нижней навигации (объекты, команда, чаты, отчёты, профиль): `Scaffold` без AppBar,
    `SafeArea(bottom: false)` → `ScreenHeader(title: l10n.…)` (крупный заголовок 30/w800, над ним можно `overline`);
  - экран поверх навигации (детали отчёта, состояния загрузки и ошибки объекта): `Scaffold` + `AppBar(title: Text(l10n.…))`;
    у чата в `title` аватар, название и подпись («3 участника» / роль собеседника);
  - свои шапки только у карточки объекта (графитовая, 250px) и у нового отчёта (крестик, если экран открыт поверх).

  Асинхронные данные:
  `.when(loading: LoadingShimmerList, error: ErrorState(message: l10n.failureMessage(error), onRetry: ref.invalidate),
  data: EmptyState, если пусто)`,
  а список оборачивается в `RefreshIndicator(onRefresh: () => ref.refresh(x.future))`.
- Отступы: `AppTheme.spacing4/8/12/16/24/32/48`; по краям экрана `AppTheme.screenPadding` (20), между карточками
  `AppTheme.cardGap` (12). Размеры: `minTouchTarget` (48), `iconButtonSize` (44), `primaryActionHeight` (56).
  Цвета и радиусы — см. «Дизайн-токены и компоненты».
- Локализация: единственный и шаблонный ARB — [app_ru.arb](lib/app/l10n/app_ru.arb). Сгенерированный код лежит
  в `lib/app/l10n/generated/` и хранится в git. В коде: `final l10n = AppLocalizations.of(context);` → `l10n.key`.
  **Все строки UI — только через l10n**, без хардкода.
- Готовое из core, вместо того чтобы писать своё: компоненты из «Дизайн-токены и компоненты», а также `EmptyState`,
  `ErrorState`, `LoadingShimmer` / `LoadingShimmerList`, `OfflineBanner`, `PhotoThumbnail` (понимает `fake:`,
  локальный путь и http; `PhotoImage` — то же фото, растянутое на родителя, `fit` по умолчанию `cover`),
  `showPhotoViewer` / `PhotoViewer` (полноэкранный просмотр: свайп вбок, зум щипком и двойным тапом через
  `InteractiveViewer`, свайп вниз закрывает, внизу подпись, автор, время и бейдж `warning`; одна реализация для
  отчётов и чата), `PhotoDraftTile` (выбранное фото: спиннер, красная метка, крестик), `showRetryDeleteSheet`
  («Повторить / Удалить» для неотправленного сообщения и несжатого фото), `DateFormatter` (ru; время отчёта —
  `reportDateTime`: «Сегодня, 11:47», «Вчера, …», «Пн, …», «27 октября, …», год только не текущий; в списке чатов
  `chatListTime`: «14:05», «Вчера», «Пн», «27 окт.»; разделитель дня в чате — `chatDay`), `Validators`, `Haptics`.
- Тесты в `test/` повторяют структуру `lib/`. Покрыты Fake-репозитории (включая коды ошибок), `Result` и `Failure`,
  перевод `Failure` в текст (`failure_messages_test.dart`), `AuthNotifier`, мутации отчётов и объектов (ошибка
  репозитория доходит до экрана со своим кодом), защита от двойной отправки, сохранение темы, `describePhotoPickError`,
  валидаторы, форматтер дат и JSON-сущности, `authRedirect` и роутер, контраст токенов, `PlatformPhotoCompressor`
  (канал подменён через `setMockMethodCallHandler`: параметры, ответ, сбой → `photoProcessing`), `parseExifDateTime`,
  `PhotoDraftsNotifier`, `takenOnAnotherDay`, просмотрщик фото отчёта, отправка фото в чате (успех, сбой загрузки
  и сжатия, повтор без повторной загрузки), сетка 1/2/4/6 фото, просмотрщик чата на нужном фото
  (`test/app/theme/contrast_test.dart`), `AvatarInitials` и бейдж статуса, правила поиска людей и «Недавние»,
  `FakeChatStore` (доставка, идемпотентность, непрочитанные, доступ при смене состава, эхо, вложения), `ChatThreadNotifier`,
  лента и поиск чатов. Компрессор в тестах — `FakePhotoCompressor` из test/helpers (копия `x.jpg` → `x.jpg.small.jpg`,
  `failing` — какие оригиналы не сжимаются, `compressed` / `deleted` — что вызывали); микрофон и динамик —
  `FakeVoiceRecorder` / `FakeVoicePlayer` (test/helpers/fake_voice.dart: уровни, звонок, разрешение, диалог
  разрешения, журнал вызовов). Машину записи тестировать в `testWidgets`: её время — таймер 100 мс, `pump` его
  двигает. Метку, которую ищут `find.bySemanticsLabel`, давать в `Semantics(container: true, …)`, иначе она
  сливается с родителем; кнопки play/pause искать по иконке. Тест, где играют чужое голосовое, в конце ждёт
  ещё секунду: задержка `markListened` у Fake. Камера и галерея —
  `FakePhotoPicker` (`shot`, `gallery`, `lost`, `cameraError`, `whileCameraOpen`) через `photoPickerProvider`;
  local storage — `SharedPreferences.setMockInitialValues({})` и настоящий `LocalStorageService`. Выбор фото на экране
  можно имитировать и через `photoDraftsProvider(scope).notifier.add(...)`. Виджет-тесты: `test/app/router_test.dart`
  (`MaterialApp.router`) и экраны через `pumpTestApp()` из [test/helpers/test_app.dart](test/helpers/test_app.dart).
  Сценарии на всём приложении (вход, выход, переходы) — через `FullApp.pump()` из
  [test/helpers/full_app.dart](test/helpers/full_app.dart), пример — `test/features/chat/presentation/chat_flow_test.dart`.
  `await router.push(...)` в тесте ждёт закрытия экрана и вешает тест: оборачивать в `unawaited`. Путь после `push`
  не виден в `currentConfiguration.uri`, проверять открытый экран (`find.byType(ChatScreen)`).
  В тестах чата создавать `FakeChatStore` без эха (`echo: false` по умолчанию) и подменять `fakeChatStoreProvider`:
  таймеры эха, оставшиеся после теста, роняют его. Кнопка отправки появляется через `AnimatedSwitcher`:
  после ввода текста нужны `pump()` и ещё `pump(200 ms)`, иначе тап не попадёт.
  Тема в них — настоящая `AppTheme.light` (параметр `theme:` подменяет её). `screens_smoke_test.dart` рендерит каждый
  экран в обеих темах; новый экран добавлять туда. Шрифты из assets flutter_test не грузит, текст рисуется тестовым шрифтом Ahem.
  Поверхность 1080 px и `textScaler` 0.7: Ahem шире настоящего шрифта, и без этого строки переполняются.
  Пока на экране крутится индикатор, `pumpAndSettle` не завершится. В таких местах нужен `pump(duration)`, а Riverpod
  перезагружает провайдер после `invalidate` только на следующем кадре, так что одного длинного `pump` мало.
  Fake-репозитории в виджет-тестах ждут до 0,8 с, поэтому после действий нужен `tester.pump(Duration(seconds: 1))`.
  Таймер задержки, оставшийся к концу теста, роняет его («Pending timers»), поэтому `FullApp.dispose()` и
  `tearDownApp` в router_test после размонтирования прокручивают ещё 3 с и только потом закрывают контейнер.
  `test/widget_test.dart` — заглушка.
- Не менять провайдеры синхронно в `initState` или `build`: на `authProvider` подписан роутер, и Riverpod падает
  на assert. Откладывать через `addPostFrameCallback`, как в splash_screen.dart.

## Дизайн-токены и компоненты
Стиль: графит, светлый «каменный» фон, сигнальный оранжевый. **Никаких хексов и `Colors.*` в экранах и виджетах.**
Палитра лежит только в [app_colors.dart](lib/app/theme/app_colors.dart), экраны читают её через тему.

**Цвета — `context.bfTheme`** ([theme_extensions.dart](lib/app/theme/theme_extensions.dart)):
- поверхности: `canvas` (фон экрана), `card`, `border` (1px у карточек, навигации, иконочных кнопок), `muted` (трек
  прогресса, чипы, поля ввода);
- текст: `textPrimary`, `textSecondary`, `textTertiary` (время, подписи);
- акцент: `accent` + `onAccent` (текст **на** оранжевом всегда тёмный, белый не проходит контраст), `accentText` (оранжевый
  как цвет текста или ссылки). Оранжевый — **только** для главного действия: основная кнопка, активная вкладка, FAB,
  бейджи непрочитанного, прогресс. Удаление и прочие разрушительные действия — `danger`, не акцент;
- графит: `graphite`, `onGraphite`, `onGraphiteSecondary` (сводка дня, вторичная кнопка, шапка объекта);
- «выбрано» и «моё» — свои смысловые токены, не `graphite`: `chipSelected` / `onChipSelected` (выбранный `BfChip`)
  и `bubbleOwn` / `onBubbleOwn` / `onBubbleOwnSecondary` (свой пузырь в чате, время и галочки). В светлой теме это
  графит с белым, в тёмной графит почти сливается с `muted`, поэтому выбранный чип инвертирован (светлая пилюля
  с тёмным текстом), а свой пузырь тёплый #3A2E26, заметно светлее `card`;
- статусы — пары `ToneColors(fg, bg)`: `active` (в работе, отчёт сдан), `paused`, `danger` (ошибка, нет отчёта), `finished`;
- `avatarFor(name)` — пастельная пара для аватара, `photoPlaceholders` — фон `fake:`-фото;
- `matchHighlight` — подложка совпадения в поиске: полупрозрачный акцент поверх `card`, текст на ней `textPrimary`.

`ColorScheme` выводится из тех же токенов (`primary` = accent, `error` = danger.fg, `surface` = canvas,
`surfaceContainer*` = card / muted), так что диалоги, меню и снэкбары Material уже в стиле.
Новую пару «текст/фон» добавлять в `contrast_test.dart`: в обеих темах нужен контраст ≥ 4.5.

**Формы:** радиусы — константы `BuildFlowThemeExtension.cardRadius` (20), `buttonRadius` (16), `inputRadius` (14),
`iconButtonRadius` (14), `photoRadius` (12), чипы и бейджи — `StadiumBorder`. Карточки плоские: рамка 1px, без тени.
Тень только у FAB.

**Типографика** ([app_text_theme.dart](lib/app/theme/app_text_theme.dart)): `headlineLarge` 30/w800 — заголовок экрана,
`headlineMedium` 26/w800 — шапка объекта и крупные цифры, `titleLarge` 20/w700 — AppBar, шиты, диалоги,
`titleMedium` 17/w700 — заголовок карточки, `bodyMedium/Large` 15, `bodySmall` 13 — подписи,
`AppTextTheme.button` 17/w800 — кнопки. Цифры (счётчики, время, проценты) — `fontFeatures: AppTextTheme.tabular`.

**Компоненты в `lib/core/widgets/`** — использовать вместо своих стилей:
- `BfButton` — во всю ширину, 56: `primary` (акцент, одна на экран, обычно закреплена внизу), `secondary` (графит),
  `outline` (белая с рамкой, тихие действия вроде «Выйти»), `text`. В диалогах — `TextButton`, не `BfButton`.
- `BfIconButton` — 44×44, радиус 14, белая с рамкой; `translucent: true` — поверх тёмной шапки или фото.
  `BfIconButtonSurface` — та же подложка для `PopupMenuButton(child: …)`.
- `BfCard` — плоская карточка; `color: t.graphite` — тёмная карточка без рамки.
- `BfTextField` — поле с заливкой `muted`.
- `StatusBadge(label, tone: StatusTone.…)` — пилюля статуса, роли или счётчика. `ProjectStatusBadge` и `RoleBadge` —
  обёртки над ней; тон статуса объекта — `projectStatusTone()`.
- `AvatarInitials(name)` — инициалы (1–2 буквы, `initialsOf()`) на пастельном фоне; `AvatarStack(names)` — стопкой с «+N»:
  до 4 аватаров по 32 px, перекрытие 20 %, обводка цветом `card`.
- `BfChip` — фильтры и быстрые шаблоны; `selected` — `chipSelected` (в светлой теме графит с белым текстом). Видимая высота 36, нажимаемая 48.
- `BfProgressBar(percent)` — акцентная полоса на треке `muted`.
- `ScreenHeader(title, overline, actions)` — шапка вкладки.
- `BfBottomNav` / `BfNavItem` — нижняя навигация (`_RoleShell` в router.dart). `badgeCount` — бейдж непрочитанного,
  `prominent` — акцентная кнопка главного действия роли (у прораба «Отчёт»).
- `UnreadBadge(count)` — акцентный счётчик непрочитанного («99+»; при 0 ничего): вкладка, строка чата, плитка чата.
- `HighlightedText(text, ranges)` — текст с подсветкой совпадений `matchHighlight` (поиск людей и чатов).
- `VoiceWaveform(bars, progress, playedColor, color, onSeek)` — полосы голосового, проигранная часть своим цветом,
  нажатие и протягивание — перемотка.
- `AppLogo` — знак приложения на сплэше и экранах входа.

## Подводные камни
- `explicit_to_json: true` включён глобально в [build.yaml](build.yaml): вложенные модели (`Report.photos`) сериализуются
  через `.toJson()`. Отдельная аннотация `@JsonSerializable(explicitToJson: true)` на моделях не нужна.
- После любой правки freezed- или json-модели обязательно запускать build_runner. `*.g.dart` и `*.freezed.dart` лежат в git.
- Демо-входы (пароль у всех `123456`): `owner@buildflow.kg`, `foreman1@`, `foreman2@`, `worker1@`, `worker2@`, `worker3@buildflow.kg`
  (Азамат Асанов есть для демо поиска: «асан» находит и его, и директора Асана Бековича; работает на «Байтике»).
- Secure storage — только через `SecureStorageService`: в нём таймауты, потому что на Xiaomi/MIUI KeyStore может зависнуть.
  Напрямую `FlutterSecureStorage` не вызывать. Сплэш тоже страхуется таймаутом (`forceUnauthenticated`).
- `FakeReportRepository` добавляет фото `fake:demo-<ts>` в отчёт без фото.
  image_picker вызывается без `maxWidth`/`imageQuality`: его собственный ресайз — без фильтрации (трещины и швы
  «лесенкой»), без потолка размера, PNG с прозрачностью и HEIC на Android 7–8 проходят как есть, EXIF копируется
  весь (с GPS и серийниками). Поэтому сжимает только `PhotoCompressor`. Снимок камеры через интент в галерею
  телефона не попадает: после отправки остаётся только сжатая копия.
  Отказ в разрешении image_picker присылает как `PlatformException(code: 'camera_access_denied')`. На Android
  бывает только этот код, потому что галерее разрешение не нужно; `photo_access_denied` приходит только на iOS.
  Текст ошибки выбирает `describePhotoPickError()` в core/photos/photo_picking.dart. При отказе в доступе снэкбар
  предлагает действие «Настройки», которое вызывает `AppSettings.openAppSettings()`.
- Плагины, которые ходят в Kotlin через JNI (`package:jni`, Pigeon JNI), ломаются только в release: R8 переименовывает
  классы, которые ищутся по имени. Так `shared_preferences_android` 2.5.1 ронял чтение и запись темы
  (`NoSuchMethodError … SharedPreferencesApiRegistrar.getAll`), исправлено в 2.5.2 (сейчас 2.5.4). Тесты и debug это
  не ловят: после обновления таких плагинов проверять release-сборку на телефоне.
- В `ref.onDispose` нельзя читать `state` и вызывать `ref.read`: нужное захватить в `build()` и держать копию
  состояния в поле (`_drafts` в `PhotoDraftsNotifier`, `_current` в `VoiceRecordingNotifier`).
- `dart format` на целый файл переписывает и нетронутый код под новый стиль форматтера: форматировать только
  свои строки, не файл целиком.
- `pickMultiImage(limit:)` требует `limit >= 2`, а старые Android лимит системного пикера игнорируют — `pickPhotos`
  обрабатывает оба случая.
- Вход по коду приглашения: ссылка «Есть код приглашения?» на экране входа ведёт на `/join` (`JoinScreen`):
  код, имя, email, пароль. Роль и компанию задаёт код (`InviteCode.role`, `companyId`), пользователь их не выбирает.
  - `generateInviteCode(role:)` принимает только `foreman` и `worker`.
  - Код: 6 символов из `inviteCodeAlphabet` (без 0/O, 1/I/L). Одноразовый, действует 7 дней.
  - Ввод нормализует `normalizeInviteCode()` (trim, верхний регистр, без пробелов и дефисов). Её вызывают
    `AuthNotifier.joinWithInviteCode` и `FakeTeamStore.redeemInvite`.
  - Ошибки: неизвестный, использованный или истёкший код → `invalidInviteCode`; занятый email → `emailTaken`,
    причём email проверяется до того, как код гасится.
  - Сервер ограничивает попытки (429 → `tooManyRequests`) и гасит код атомарно. Fake этого не моделирует.
  - Удалённый участник в Fake всё ещё может войти. Сервер его банит: вход — `accountDisabled` («Доступ закрыт»).
- Если в shell одной роли несколько вкладок с `FloatingActionButton`, у них должен быть `heroTag: null`.
  `StatefulShellRoute` держит все вкладки живыми, и два одинаковых hero-тега роняют любой переход между страницами.
- Название приложения — `l10n.appName`, в том числе в `MaterialApp.onGenerateTitle`. Можно склеивать строки l10n
  с разделителями (`'${l10n.foremenCount}: $n'`), но новые слова в такие строки не добавлять.
- В `build.gradle.kts` стоит `minSdk = flutter.minSdkVersion` (в Flutter 3.47.5 это 24), хотя в коммите было `23`.
  flutter_secure_storage нужен ≥ 23, так что работает, но если сменить версию Flutter, проверь.
- `flutter build apk` предупреждает, что `app_settings` применяет Kotlin Gradle Plugin, и будущие версии Flutter
  такие плагины собирать не будут. Перед обновлением Flutter проверь его новую версию.
- AndroidManifest: `INTERNET`, `CAMERA` и `RECORD_AUDIO`. `applicationId = com.example.buildflow`, release подписан debug-ключом.
  `network_security_config.xml` пускает открытый HTTP только на `127.0.0.1`, `localhost` и `10.0.2.2` (локальный
  Supabase через `adb reverse` или эмулятор), остальное — только HTTPS.
- Тесты репозиториев Supabase — настоящий `SupabaseClient` поверх `MockClient` (`FakeSupabase` в test/helpers:
  `rpc` / `rpcFails` / `function` / `on`, `FakeReply.auth` для ошибок GoTrue, `signIn(userId)` кладёт сессию; Dio
  Storage идёт в те же обработчики). PostgREST читает `response.request`, поэтому `http.Response` отдаётся с `request:`.
  Тестовый `SupabaseClient` и шлюз закрывать (`dispose`), иначе тест не завершится.
- `AppLifecycleListener` проверяет переходы: в тесте фон и возврат — цепочкой inactive → hidden → paused → hidden →
  inactive → resumed через `binding.handleAppLifecycleStateChanged`.
- `integration/` анализатор не считает тестовой папкой (`visibleForTesting` там — с `ignore`), и `flutter test` без
  пути её не запускает.
- Inter 4.1 (статические TTF из релиза rsms/inter) лежит в `assets/fonts/inter/`, начертания 400, 500, 600, 700 и 800,
  рядом лицензия `OFL.txt`. main.dart регистрирует её в `LicenseRegistry`. Для нового начертания (например, 300) нужно
  добавить файл и строку в `fonts:` в pubspec.yaml. Иначе Flutter возьмёт ближайшее начертание или сымитирует жирность.
  Семейство задаётся в `AppTextTheme` на каждом стиле, а не только в `ThemeData`: AppBar и кнопки берут стили прямо оттуда.

## Текущее состояние
Готово (на Fake-данных и на локальном Supabase): вход, регистрация и вход по коду приглашения, сплэш, объекты (список со сводкой дня и фильтром,
детали, статус, готовность, команда объекта), команда и коды приглашения по ролям, поиск людей по имени и фамилии, отчёты (создание с камерой или галереей, список по дням, детали, время съёмки фото), профиль и тема
(сохраняется между запусками), три роли, чат этапов 1–3 (чаты объектов и личные, текст, фото, голосовые, статусы, непрочитанные),
сжатие фото на устройстве (Android), общий полноэкранный просмотр фото.
Визуальный стиль — см. «Дизайн-токены и компоненты».
Бэкенд на Supabase (локально): схема, RLS, RPC всех пяти фич, Storage, Realtime, Edge Functions `join` и
`remove-member`, демо-данные, тесты pgTAP и смоук — см. «Бэкенд (Supabase)». Клиент подключён: `Supabase*Repository`,
сессия, загрузки и подписанные ссылки, Realtime с догрузом, интеграционный тест.
Заглушки и пробелы: облачный проект Supabase (только локальный стек), пуши, сжатие фото на iOS, черновики отчётов
(`DraftReport` есть в репозитории, но UI нет), applicationId и подпись Android-релиза.
Подробности и этапы — в [PROGRESS.md](PROGRESS.md); он отстаёт от кода, сверяйся с кодом.

## Правила работы
- После изменений запускать `flutter analyze` и `flutter test`. Не завершать задачу с ошибками анализатора
  или упавшими тестами.
- После изменений в `supabase/` — `npx supabase@2.122.0 db reset`, `test db` и `node supabase/tests/edge/smoke.mjs`
  (после новой Edge Function или правки `config.toml` — сначала `stop` и `start`).
- Если задача затрагивает нативный код (`android/`), плагины (pubspec.yaml, pubspec.lock) или хранилище
  (`shared_preferences`, secure storage), перед её завершением проверить release-сборку на устройстве
  (`flutter run --release`): тесты и debug не проходят через R8, и такие ошибки видны только в release.
- Не коммитить без явной просьбы.
- Не добавлять пакеты в pubspec.yaml без согласования.
- Новый код следует существующей архитектуре (feature / data / domain / presentation) и возвращает `Result<T>` из репозиториев.
- Тексты UI добавлять в `app_ru.arb`, затем запускать `flutter gen-l10n`.
- Отвечать на русском.
