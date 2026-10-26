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
flutter_secure_storage, shared_preferences, image_picker, google_fonts, intl, very_good_analysis.
Подключены, но в `lib/` не используются: dio, flutter_image_compress, cached_network_image, uuid.

```
lib/app/       app.dart (ProviderScope + MaterialApp.router), router.dart, routes.dart, theme/, l10n/
lib/core/      config.dart, error/ (Result, Failure), storage/ (secure, local, storage_providers), utils/, widgets/
lib/features/<фича>/data/          Fake*Repository, Api*Repository
                    domain/        entities/ (freezed), repositories/ (абстрактные интерфейсы)
                    presentation/  providers/, screens/, widgets/
```
Фичи: `auth`, `projects`, `reports`, `team`, `profile` (у profile есть только `presentation/`).

**Ошибки — `Result<T>`** ([lib/core/error/result.dart](lib/core/error/result.dart)): sealed `Success(data)` / `Err(failure)`.
Failure — sealed, см. [failures.dart](lib/core/error/failures.dart): `NetworkFailure`, `ServerFailure(statusCode)`,
`AuthFailure`, `StorageFailure`, `ValidationFailure`, `UnknownFailure`.
```dart
Future<Result<Project>> createProject(...);                  // интерфейс репозитория
return const Err(ValidationFailure(message: 'Неверный код')); // ошибка
return Success(project);
result.when(success: (p) => ..., failure: (f) => ...);       // у вызывающего
```
Репозитории никогда не бросают исключений. В `AsyncNotifier.build()` Err превращается в `throw Exception(f.message)`,
чтобы попасть в `AsyncValue.error`. Мутации нотифайеров возвращают `Future<bool>`.

**Репозитории и DI:**
- Реализацию выбирает только `xxxRepositoryProvider` в `presentation/providers/<фича>_provider.dart`
  (`authRepositoryProvider` лежит в auth_provider.dart): `kUseMockData ? FakeXxxRepository() : ApiXxxRepository()`.
  Флаг — в [config.dart](lib/core/config.dart). `ProviderScope` в app.dart без overrides.
- Сервисы хранилищ создаются только в [storage_providers.dart](lib/core/storage/storage_providers.dart):
  `secureStorageProvider` и `localStorageProvider`. `FakeAuthRepository` получает `SecureStorageService` через
  `secureStorageProvider`. Напрямую `SecureStorageService()` / `LocalStorageService()` не создавать (кроме тестов).
- Новый репозиторий подключать так же: интерфейс в domain, `Fake*` и `Api*` в data, выбор в его провайдере.
  В тестах подменять через `ProviderScope(overrides: [xxxRepositoryProvider.overrideWithValue(...)])`.
- `Api*Repository` есть у всех четырёх фич, но это заглушки: все методы возвращают
  `Err(ServerFailure(message: 'API not implemented'))`. Контракт: [docs/api-contract.md](docs/api-contract.md).
- Fake-репозитории изолированы друг от друга, но используют общие ID (`user-owner-1`, `user-foreman-1`, `project-1`…).
  Есть искусственная задержка. Данные живут только в памяти и при перезапуске сбрасываются.

**Роли:** `UserRole { owner, foreman, worker }` ([user_role.dart](lib/features/auth/domain/entities/user_role.dart)).
UI-хелперы — `label(l10n)`, `icon`, `color`, `RoleBadge` — в [role_label.dart](lib/features/auth/presentation/role_label.dart).
- [router.dart](lib/app/router.dart): по одному `StatefulShellRoute` (`_shell`) на роль, у каждой своя нижняя навигация
  (`_RoleShell`). Owner: объекты, команда, отчёты, профиль. Foreman: объекты, новый отчёт, отчёты, профиль.
  Worker: объекты, отчёты, профиль.
- Пути — в [routes.dart](lib/app/routes.dart): `/owner/*`, `/foreman/*`, `/worker/*`, плюс `Routes.homeFor(role)` и `prefixFor(role)`.
- Навигацию по авторизации делает только роутер. Чистая функция `authRedirect(AuthState, path)` в router.dart:
  статус `initial` → остаёмся на сплэше; нет пользователя → `/login`; сплэш, login или register → home роли;
  префикс чужой роли → home роли. Тесты лежат в `test/app/router_test.dart`.
- `routerProvider` создаёт `GoRouter` один раз. `refreshListenable` срабатывает, когда в `authProvider` меняется
  `(status, user)`. После login, register, logout и restoreSession **не вызывать `context.go`**: достаточно сменить
  состояние в `AuthNotifier`.
- `/projects/:id` и `/reports/:id` — роуты верхнего уровня вне shell, поэтому открываются поверх навигации.
  Открывать через `context.push(Routes.project(id))` / `Routes.report(id)`.
- Видимость данных по ролям — в провайдерах, а не в роутере: `canSeeProject()` в project_provider.dart.
  `reportsProvider` отдаёт отчёты только по видимым объектам.

## Соглашения
- Файлы в snake_case. Классы: `XxxScreen`, `XxxRepository` (интерфейс), `FakeXxxRepository` / `ApiXxxRepository`,
  `XxxNotifier`, `xxxProvider`. Приватные виджеты `_Xxx` лежат в том же файле. Разделители секций: `// ── Title ───`.
- Импорты только абсолютные: `package:buildflow/...`.
- Сущности: `@freezed abstract class X with _$X` + `factory X.fromJson`, `part 'x.freezed.dart'; part 'x.g.dart';`.
  Перечисления — обычные Dart enum с геттерами (`status.isActive`, `role.isOwner`).
- Провайдеры — top-level `final` в `presentation/providers/<фича>_provider.dart`, не в файлах экранов и виджетов.
  Провайдеры core-сервисов — в `lib/core/<модуль>/`, `routerProvider` — в router.dart:
  - список: `AsyncNotifierProvider<XxxNotifier, List<X>>`; в `build()` вызывать `ref.watch(currentUserProvider)`,
    чтобы список перезагружался при смене пользователя;
  - один элемент: `Provider.family<AsyncValue<X?>, String>`, выводится из списка (`projectByIdProvider`, `reportByIdProvider`);
  - после успешной мутации вызывать `ref.invalidateSelf()`.
  - Исключения: auth — legacy `StateNotifierProvider<AuthNotifier, AuthState>`, `inviteCodeProvider` — `StateProvider`.
    `themeModeProvider` — `StateProvider` в profile_provider.dart, его читает app.dart.
- Экраны: `ConsumerWidget`; если есть форма или контроллеры — `ConsumerStatefulWidget`. Каркас:
  `Scaffold` + `AppBar(title: Text(l10n.…))`. Асинхронные данные:
  `.when(loading: LoadingShimmerList, error: ErrorState(onRetry: ref.invalidate), data: EmptyState, если пусто)`,
  а список оборачивается в `RefreshIndicator(onRefresh: () => ref.refresh(x.future))`.
- Отступы: `AppTheme.spacing4/8/12/16/24/32/48`, плюс `minTouchTarget` и `primaryActionHeight`.
  Цвета: `Theme.of(context).colorScheme`; success / warning / draft и радиусы — через `context.bfTheme`.
- Локализация: единственный и шаблонный ARB — [app_ru.arb](lib/app/l10n/app_ru.arb). Сгенерированный код лежит
  в `lib/app/l10n/generated/` и хранится в git. В коде: `final l10n = AppLocalizations.of(context);` → `l10n.key`.
  **Все строки UI — только через l10n**, без хардкода.
- Готовое из core, вместо того чтобы писать своё: `BfButton`, `BfCard`, `BfTextField`, `EmptyState`, `ErrorState`,
  `LoadingShimmer` / `LoadingShimmerList`, `OfflineBanner`, `PhotoThumbnail` (понимает `fake:`, локальный путь и http),
  `DateFormatter` (ru), `Validators`, `Haptics`.
- Тесты в `test/` повторяют структуру `lib/`. Покрыты Fake-репозитории, `Result`, валидаторы, форматтер дат и
  JSON-сущности, `authRedirect` и роутер. Виджет-тесты есть только в `test/app/router_test.dart`: там поднимается
  `MaterialApp.router` с `ThemeData(extensions: [BuildFlowThemeExtension.light])` без `AppTheme`, потому что
  google_fonts тянет шрифты из сети. Поверхность 1080 px и `textScaler` 0.7: тестовый шрифт Ahem шире настоящего,
  и без этого строки переполняются.
  `test/widget_test.dart` — заглушка.
- Не менять провайдеры синхронно в `initState` или `build`: на `authProvider` подписан роутер, и Riverpod падает
  на assert. Откладывать через `addPostFrameCallback`, как в splash_screen.dart.

## Подводные камни
- `explicit_to_json: true` включён глобально в [build.yaml](build.yaml): вложенные модели (`Report.photos`) сериализуются
  через `.toJson()`. Отдельная аннотация `@JsonSerializable(explicitToJson: true)` на моделях не нужна.
- После любой правки freezed- или json-модели обязательно запускать build_runner. `*.g.dart` и `*.freezed.dart` лежат в git.
- Демо-входы (пароль у всех `123456`): `owner@buildflow.kg`, `foreman1@`, `foreman2@`, `worker1@`, `worker2@buildflow.kg`.
- Secure storage — только через `SecureStorageService`: в нём таймауты, потому что на Xiaomi/MIUI KeyStore может зависнуть.
  Напрямую `FlutterSecureStorage` не вызывать. Сплэш тоже страхуется таймаутом (`forceUnauthenticated`).
- `NewReportScreen` подставляет фото `fake:demo-<ts>`, если пользователь ничего не выбрал.
  Сжатие сейчас только через `imageQuality: 85` и `maxWidth/Height: 1920` в image_picker.
- `joinWithInviteCode` есть в репозитории, но UI его не вызывает. В фейке код проверяется только по длине ≥ 6,
  а роль всегда `foreman`.
- Хардкод строк, который надо вынести в l10n, а не копировать: `auth_provider.dart` («Что-то пошло не так»),
  `new_report_screen.dart` («Не удалось выбрать фото»), `splash_screen.dart`, подсказка демо-входов в `login_screen.dart`,
  дефолтный `retryLabel` в `ErrorState`. Сообщения Failure в Fake-репозиториях тоже на русском и показываются в UI.
- В `build.gradle.kts` стоит `minSdk = flutter.minSdkVersion` (в Flutter 3.47.5 это 24), хотя в коммите было `23`.
  flutter_secure_storage нужен ≥ 23, так что работает, но если сменить версию Flutter, проверь.
- AndroidManifest: только `INTERNET` и `CAMERA`. `applicationId = com.example.buildflow`, release подписан debug-ключом.
- `google_fonts` (Inter) без шрифтов в assets: по умолчанию он грузит их из сети.

## Текущее состояние
Готово на Fake-данных: вход и регистрация, сплэш, объекты (список, детали, статус, команда объекта), команда
и коды приглашения, отчёты (создание с камерой или галереей, список по дням, детали), профиль и тема, три роли.
Заглушки и пробелы: Api-репозитории (все четыре — заглушки), клиент Dio, сжатие фото (flutter_image_compress),
загрузка сетевых фото (cached_network_image), черновики отчётов (`DraftReport` есть в репозитории, но UI нет),
applicationId и подпись Android-релиза.
Подробности и этапы — в [PROGRESS.md](PROGRESS.md); он отстаёт от кода, сверяйся с кодом.

## Правила работы
- После изменений запускать `flutter analyze` и `flutter test`. Не завершать задачу с ошибками анализатора
  или упавшими тестами.
- Не коммитить без явной просьбы.
- Не добавлять пакеты в pubspec.yaml без согласования.
- Новый код следует существующей архитектуре (feature / data / domain / presentation) и возвращает `Result<T>` из репозиториев.
- Тексты UI добавлять в `app_ru.arb`, затем запускать `flutter gen-l10n`.
- Отвечать на русском.
