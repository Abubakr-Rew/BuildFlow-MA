# BuildFlow — контекст для Claude

## О проекте
Flutter-приложение для ежедневных фото-отчётов со стройки для небольших строительных компаний Бишкека.
Прораб снимает объект и отправляет отчёт, владелец видит прогресс за день. Интерфейс только на русском.
Бэкенда пока нет: всё работает на in-memory Fake-репозиториях. Основная цель — Android (тестируем на Xiaomi).

## Команды
```bash
flutter pub get                                           # зависимости
dart run build_runner build --delete-conflicting-outputs  # freezed / json_serializable
flutter gen-l10n                                          # после правки app_ru.arb
flutter run                                               # на подключённом устройстве
flutter analyze                                           # цель: "No issues found!" (~2 мин)
flutter test                                              # все тесты
flutter test test/core/error/result_test.dart             # один файл
flutter test --plain-name "round-trip"                    # тесты по имени
flutter build apk --release                               # APK → build/app/outputs/flutter-apk/
```

## Архитектура
**Стек:** Flutter 3.47 / Dart ^3.13, flutter_riverpod 2.6, go_router 14, freezed 4 + json_serializable,
flutter_secure_storage, shared_preferences, image_picker, app_settings, intl, very_good_analysis.
Шрифт Inter лежит в `assets/fonts/inter/`, google_fonts не используется.
`app_settings` нужен только для того, чтобы открыть системные настройки приложения после отказа в разрешении.
`uuid` генерирует `clientId` сообщений чата.
Подключены, но в `lib/` не используются: dio, cached_network_image. Сжатие фото — свой Kotlin-канал
(см. «Фото»), `flutter_image_compress` удалён.

```
lib/main.dart  ProviderContainer, восстановление темы до первого кадра, runApp
lib/app/       app.dart (MaterialApp.router), router.dart, routes.dart, theme/, l10n/
lib/core/      config.dart, error/ (Result, Failure), photos/ (сжатие, выбор, черновики фото),
               storage/ (secure, local, storage_providers), utils/, widgets/
android/app/src/main/kotlin/…/PhotoCompressor.kt   нативное сжатие фото (канал buildflow/photos)
lib/features/<фича>/data/          Fake*Repository, Api*Repository
                    domain/        entities/ (freezed), repositories/ (абстрактные интерфейсы)
                    presentation/  providers/, screens/, widgets/
```
Фичи: `auth`, `projects`, `reports`, `team`, `chat`, `profile` (у profile есть только `presentation/`).

**Ошибки — `Result<T>`** ([lib/core/error/result.dart](lib/core/error/result.dart)): sealed `Success(data)` / `Err(failure)`.
`Failure` ([failures.dart](lib/core/error/failures.dart)) — один класс. Что увидит пользователь, решает `code`
(enum `FailureCode`). `message` нужен только для логов и отладки и в UI не показывается. Есть ещё `statusCode`
и `stackTrace`. Коды: `network`, `timeout`, `server`, `invalidCredentials`, `emailTaken`, `invalidInviteCode`,
`sessionExpired`, `forbidden`, `notFound`, `validation`, `tooManyRequests`, `photoProcessing` (только клиент: фото
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
  (`authRepositoryProvider` лежит в auth_provider.dart): `kUseMockData ? FakeXxxRepository() : ApiXxxRepository()`.
  Флаг — в [config.dart](lib/core/config.dart). `ProviderContainer` создаётся в main.dart без overrides
  и передаётся в `UncontrolledProviderScope`.
- Сервисы хранилищ создаются только в [storage_providers.dart](lib/core/storage/storage_providers.dart):
  `secureStorageProvider` и `localStorageProvider`. `FakeAuthRepository` получает `SecureStorageService` через
  `secureStorageProvider`. Напрямую `SecureStorageService()` / `LocalStorageService()` не создавать (кроме тестов).
- Новый репозиторий подключать так же: интерфейс в domain, `Fake*` и `Api*` в data, выбор в его провайдере.
  В тестах подменять через `ProviderScope(overrides: [xxxRepositoryProvider.overrideWithValue(...)])`.
- `Api*Repository` есть у всех пяти фич с данными, но это заглушки: все методы возвращают
  `Err(Failure(FailureCode.server, message: 'API not implemented'))`, потоки чата — `Stream.error` с той же ошибкой.
  Контракт: [docs/api-contract.md](docs/api-contract.md).
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

**Чат** (`lib/features/chat/`, этапы 1–2 из 4: основа, текст, фото; дальше голосовые, карточки отчётов):
- Сущности `Chat` (`direct` | `project`) и `Message` (`kind`: `text`, `photo`, `voice`, `report`, `system`).
  `photo` — до `maxPhotosPerMessage` (10) вложений в `attachments` (`url`, `width`, `height`), `text` — подпись.
  `reportId` и `durationMs` — задел на этапы 3–4. Чего клиент не умеет показать
  (`!kind.isSupported`), то рисуется пузырём «Неподдерживаемое сообщение».
- `ChatRepository` — потоки `watchChats()` / `watchMessages(chatId)` (последние `chatPageSize` = 50) и `Result`-методы
  `loadOlder`, `uploadPhoto(CompressedPhoto, onProgress:)` → вложение, `send(text:, attachmentIds:)` (идемпотентно
  по `clientId`), `getOrCreateDirect`, `markRead`. Потоки не бросают: отказ —
  событие ошибки с `Failure` (`forbidden`, когда пользователя исключили), оно попадает в `AsyncValue.error`.
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
    загрузивший и только один раз, иначе `forbidden`. В демо-истории есть сообщения с 1, 2, 3 и 6 фото (`fake:`).
  - Флаги в config.dart (только при `kUseMockData`): `kFakeChatEcho` — собеседник в личном чате «читает» через 1–2 с
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
- Экран чата — `CustomScrollView(reverse: true, center: история)`: история растёт вверх, сообщения, пришедшие, пока
  человек читает выше, — в отдельный sliver ниже центра, поэтому не сдвигают текст; вместо этого плашка
  «Новые сообщения ↓». Своё сообщение или новое, когда пользователь внизу, переносит якорь и прыгает вниз.
  Ленту строит чистая `buildTimeline()` (chat_timeline.dart): разделители дней, группы одного автора (пауза ≤ 10 мин).
- Поле ввода `ChatComposer`: `leading` («+» → «Камера / Галерея», галерея до 10), `fieldSuffix` (камера в поле), `top`
  (полоса `PhotoDraftTile` выбранных фото), `hasAttachments` (кнопка отправки без текста, подсказка «Подпись»),
  `trailingWhenEmpty` (этап 3 — микрофон). `onSend` возвращает `bool`: поле очищается, только если ушло, поэтому
  при фото с ошибкой сжатия подпись остаётся, а снэкбар просит повторить или убрать фото.
- Фото в ленте — `MessagePhotos` (message_photos.dart): раскладка `photoGridRows()` — 1 по пропорциям (0.6–1.8),
  2 рядом, 3 как 1 + 2, от 4 — 2 × 2 и «+N» на последней ячейке. Подпись под фото в пузыре; без подписи время
  и галочки на графитовой плашке поверх фото. Нажатие открывает `PhotoViewer` на этом фото (Hero —
  `chatPhotoHeroTag`). В списке чатов — «Фото» / «3 фото · подпись» с иконкой камеры (`chatPreview` отдаёт
  `prefix`, `text`, `isPhoto`).
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

## Соглашения
- Файлы в snake_case. Классы: `XxxScreen`, `XxxRepository` (интерфейс), `FakeXxxRepository` / `ApiXxxRepository`,
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
  `failing` — какие оригиналы не сжимаются, `compressed` / `deleted` — что вызывали); камера и галерея —
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
  - Удалённый участник в Fake всё ещё может войти. Как должен вести себя сервер — в api-contract.md.
- Если в shell одной роли несколько вкладок с `FloatingActionButton`, у них должен быть `heroTag: null`.
  `StatefulShellRoute` держит все вкладки живыми, и два одинаковых hero-тега роняют любой переход между страницами.
- Название приложения — `l10n.appName`, в том числе в `MaterialApp.onGenerateTitle`. Можно склеивать строки l10n
  с разделителями (`'${l10n.foremenCount}: $n'`), но новые слова в такие строки не добавлять.
- В `build.gradle.kts` стоит `minSdk = flutter.minSdkVersion` (в Flutter 3.47.5 это 24), хотя в коммите было `23`.
  flutter_secure_storage нужен ≥ 23, так что работает, но если сменить версию Flutter, проверь.
- `flutter build apk` предупреждает, что `app_settings` применяет Kotlin Gradle Plugin, и будущие версии Flutter
  такие плагины собирать не будут. Перед обновлением Flutter проверь его новую версию.
- AndroidManifest: только `INTERNET` и `CAMERA`. `applicationId = com.example.buildflow`, release подписан debug-ключом.
- Inter 4.1 (статические TTF из релиза rsms/inter) лежит в `assets/fonts/inter/`, начертания 400, 500, 600, 700 и 800,
  рядом лицензия `OFL.txt`. main.dart регистрирует её в `LicenseRegistry`. Для нового начертания (например, 300) нужно
  добавить файл и строку в `fonts:` в pubspec.yaml. Иначе Flutter возьмёт ближайшее начертание или сымитирует жирность.
  Семейство задаётся в `AppTextTheme` на каждом стиле, а не только в `ThemeData`: AppBar и кнопки берут стили прямо оттуда.

## Текущее состояние
Готово на Fake-данных: вход, регистрация и вход по коду приглашения, сплэш, объекты (список со сводкой дня и фильтром,
детали, статус, готовность, команда объекта), команда и коды приглашения по ролям, поиск людей по имени и фамилии, отчёты (создание с камерой или галереей, список по дням, детали, время съёмки фото), профиль и тема
(сохраняется между запусками), три роли, чат этапов 1–2 (чаты объектов и личные, текст, фото, статусы, непрочитанные),
сжатие фото на устройстве (Android), общий полноэкранный просмотр фото.
Визуальный стиль — см. «Дизайн-токены и компоненты».
Заглушки и пробелы: Api-репозитории (все пять — заглушки), WebSocket-клиент чата, клиент Dio, загрузка в хранилище
по `POST /uploads`, показ сетевых фото (cached_network_image), сжатие фото на iOS, черновики отчётов (`DraftReport`
есть в репозитории, но UI нет), applicationId и подпись Android-релиза.
Подробности и этапы — в [PROGRESS.md](PROGRESS.md); он отстаёт от кода, сверяйся с кодом.

## Правила работы
- После изменений запускать `flutter analyze` и `flutter test`. Не завершать задачу с ошибками анализатора
  или упавшими тестами.
- Не коммитить без явной просьбы.
- Не добавлять пакеты в pubspec.yaml без согласования.
- Новый код следует существующей архитектуре (feature / data / domain / presentation) и возвращает `Result<T>` из репозиториев.
- Тексты UI добавлять в `app_ru.arb`, затем запускать `flutter gen-l10n`.
- Отвечать на русском.
