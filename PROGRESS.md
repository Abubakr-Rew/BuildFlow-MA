# BuildFlow — прогресс

Обновлено: 2026-10-28. Правила работы и архитектура — в [CLAUDE.md](CLAUDE.md).

## Как запустить
```bash
flutter pub get
flutter run          # на подключённом Xiaomi
flutter analyze      # цель: "No issues found!"
flutter test         # 152 теста
```

Демо-входы (FakeAuthRepository), пароль у всех `123456`:
`owner@buildflow.kg` (директор), `foreman1@` / `foreman2@` (прорабы), `worker1@` / `worker2@buildflow.kg` (строители).

## Текущее состояние
Готово на Fake-данных:
- вход, регистрация, вход по коду приглашения (роль из кода), сплэш с защитой от зависания KeyStore на MIUI;
- три роли со своей навигацией;
- объекты: список, детали, статус, состав;
- команда и одноразовые коды приглашения для прораба или строителя;
- отчёты: камера или галерея, список по дням, детали; при отказе в доступе к камере снэкбар с переходом в настройки;
- профиль и тема (сохраняется между запусками).

Ошибки типизированы: `Failure` + `FailureCode`. В UI ошибка выводится только через `l10n.failureMessage`. Мутации возвращают `Result<T>`.

Заглушки:
- Api-репозитории (все четыре);
- клиент Dio;
- сжатие фото;
- загрузка сетевых фото;
- черновики отчётов (UI нет);
- applicationId и подпись Android-релиза.

## Сделано 2026-10-28
- `21e23e5` fix: prevent double submit — обработчики мутаций выходят сразу, если запрос уже идёт: новый отчёт, состав объекта, статус объекта, удаление участника, код приглашения. Пока меняется статус, редактирование состава заблокировано. В отчёт уходит копия списка фото.
- В `docs/api-contract.md` записано, что `DELETE /team/members/:id` сам убирает участника из всех объектов. Клиентская очистка в `MembersNotifier.removeMember` остаётся до настоящего API.
- `f2d8757` chore(theme): bundle Inter font instead of google_fonts — Inter 4.1, статические начертания 400–800 в `assets/fonts/inter/` с `OFL.txt` (зарегистрирован в `LicenseRegistry`). Пакет `google_fonts` удалён, шрифт больше не грузится из сети. Виджет-тесты поднимают настоящую `AppTheme.light`. Debug APK при чистой сборке: 167 939 752 → 166 294 729 байт (−1,6 МБ: шрифты +1,07 МБ сжатыми, Dart-код −2,7 МБ).
- `26c8947` fix(ui): avoid duplicate FAB hero tags in shells — у директора вкладки «Объекты» и «Команда» живут в одном shell, и их FAB с одинаковым hero-тегом роняли любой переход между страницами. Нашёл сценарный тест входа по коду.
- `1d21429` feat(auth): join with an invite code — экран `/join` со ссылкой «Есть код приглашения?» на экране входа. Роль и компанию задаёт код (`InviteCode.role`), директор выбирает роль при генерации. Fake: общий `FakeTeamStore` для команды и auth, код одноразовый, живёт 7 дней, без похожих символов (0/O, 1/I/L), ввод нормализуется (пробелы, дефисы, регистр). Новый участник сразу виден в команде. В api-contract: ограничение попыток на `POST /auth/join` (10 в минуту, 429 → новый `FailureCode.tooManyRequests`), атомарное погашение кода, отзыв сессий удалённого участника.

## Сделано 2026-10-26
Функциональность и исправления:
- `3315b91` fix(auth): guard secure storage and session restore against hangs
- `b6d3b61` feat(auth): add worker role with role-based navigation and visibility
- `ae4a9c5` feat(reports): pick real photos via image_picker
- `490045d` feat: add project and report detail screens
- `d48e6b2` feat(team): rework team screen with invites by role and member removal
- `39f8fa4` chore: add app config flags and use Flutter default minSdk
- `4a9839a` docs: add CLAUDE.md with project context for Claude Code
- `720674f` fix(models): enable explicit_to_json for nested serialization
- `c5ea798` refactor(di): select repository implementations via kUseMockData
- `e9e3dfc` fix(router): react to auth changes via refreshListenable
- `cf00fc4` chore: update .gitignore
- `d6af151` chore: track pubspec.lock

Уборка кода:
- `ff37222` refactor: move providers out of screen files — провайдеры хранилищ перенесены в `core/storage/storage_providers.dart`, тема — в `profile_provider.dart`.
- `cc43e27` refactor(auth): move currentUserProvider to auth_provider
- `1356b93` refactor(auth): migrate AuthNotifier from StateNotifier to Notifier — legacy-провайдеров больше нет, неиспользуемый `inviteCodeProvider` удалён.
- `fd0d078` chore: normalize line endings — `.gitattributes`, LF во всём репозитории.
- `ffb4fb4` feat(profile): persist theme mode — тема восстанавливается в `main()` до первого кадра.
- `7a59299` fix(l10n): move hardcoded UI strings to app_ru.arb
- `819a433` feat(reports): explain denied camera/photo access
- `7518653` feat(reports): open app settings from denied-access snackbar — добавлен пакет `app_settings`.
- `fb41619` refactor(core): typed failures with localized messages — в `docs/api-contract.md` добавлена таблица «HTTP-ответ → FailureCode».
- `6a0b494` refactor: return Result from mutations

## Проверить на устройстве
- Вход по коду: директор создаёт код для строителя, выход, «Есть код приглашения?» → вход открывает экран строителя, а у директора он появляется в команде.
- Шрифт Inter без сети: при первом запуске в режиме полёта текст должен сразу быть Inter (раньше google_fonts качал его из сети). Заголовок на сплэше — ExtraBold.
- Тёмная тема после перезапуска приложения: должна открыться сразу, без вспышки светлой.
- Отказ в доступе к камере: должен показаться снэкбар на 8 с, а кнопка «Настройки» — открыть настройки BuildFlow.

## Следующие шаги
1. **README:** запуск, демо-входы, архитектура кратко, ссылка на CLAUDE.md.
2. **Сжатие фото** через `flutter_image_compress`. Сейчас есть только `imageQuality: 85` и 1920 px в image_picker.
3. **Офлайн-очередь отчётов:** `DraftReport` и `localStorageProvider` уже есть, нужны UI, повторная отправка и `OfflineBanner`.
4. **Android-релиз:** `applicationId` вместо `com.example.buildflow`, подпись release-ключом (сейчас debug).
5. **Настоящий API.**
   - Клиент Dio с интерсепторами: при `sessionExpired` — logout. Перевод ответов в `FailureCode` — по таблице в `docs/api-contract.md`.
   - `kUseMockData` через `--dart-define`.
   - Реализации `Api*Repository`.
   - `PATCH /projects/:id` для частичных обновлений объекта: статус и состав отправляются отдельно, только изменённые поля. Сейчас `updateProject` шлёт объект целиком, и параллельные изменения (смена статуса и `removeMember`, который чистит составы) могут затереть друг друга. На экране объекта это закрыто блокировкой, в общем случае — нет.
6. **Обновление на Riverpod 3.** Legacy-провайдеров уже нет, всё на `Notifier`/`AsyncNotifier`. Проверить `ref.mounted` в мутациях после `await`.

При обновлении Flutter: `app_settings` и `flutter_image_compress_common` применяют Kotlin Gradle Plugin, а будущие версии Flutter такие плагины собирать не будут. Перед обновлением проверить их новые версии.
