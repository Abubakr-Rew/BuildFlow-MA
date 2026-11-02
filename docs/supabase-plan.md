# Бэкенд на Supabase — план

Принят 2026-11-02. Контракт, который бэкенд воспроизводит, — [api-contract.md](api-contract.md).
Код — в [supabase/](../supabase/). Как запустить и прогнать тесты — в разделе «Локальный запуск» в конце.

## Решения
- Клиент будет ходить в Supabase через `supabase_flutter`. Пакет добавим, когда будем подключать клиент.
- Supabase CLI запускается через `npx supabase@2.122.0`, глобально не ставится. Пока работаем только локально,
  облачный проект привяжем отдельным шагом перед пилотом.
- Подтверждение email выключено (`[auth.email] enable_confirmations = false`). **Пересмотреть перед пилотом.**

**Перед пилотом:**
- подтверждение email;
- какой заголовок несёт настоящий IP клиента в Edge Functions облачного проекта (`join` берёт
  `cf-connecting-ip`, иначе последний адрес `X-Forwarded-For`). Если это окажется адрес внутреннего прокси,
  лимит по IP станет общим на всех;
- привязка облачного проекта и `supabase db push`.
- Срок access-токена — 15 минут (`[auth] jwt_expiry = 900`).
- В `auth.users` и `auth.sessions` SQL не пишет. Блокировку входа и выход со всех устройств делает Edge Function
  `remove-member` через admin API.

## Принципы
- **Источник правды — Postgres.** RLS включён на каждой таблице `public`. У `anon` нет прав ни на одну таблицу,
  у `authenticated` есть только `SELECT`. Всё, что меняет данные, идёт через RPC.
- **Чтение под RLS.** Функции чтения (`get_*`) выполняются с правами вызывающего (`security invoker`), поэтому
  видимость задают только политики, и pgTAP проверяет именно их.
- **Запись через RPC с `security definer`.** Такие функции сами проверяют права и роль и меняют связанные данные
  в одной транзакции: состав чата вместе с составом объекта, системные сообщения, погашение кода приглашения.
- **Права на функции.** Ни одна функция не выполняется по умолчанию: `alter default privileges` снимает `EXECUTE`
  с `public`, `anon` и `authenticated`. Каждая функция явно делает `revoke execute … from public, anon`, а
  `grant execute … to authenticated` получают только те, что вызывает клиент. Служебные RPC для Edge Functions
  доступны только `service_role`. Тест сверяет списки.
- **Первая строка каждой клиентской функции — `private.require_user()`.** Она проверяет, что `auth.uid()` не
  `null` (иначе 401), что у пользователя есть профиль и что он не удалён из компании (иначе 403).
- **Хелперы RLS, триггеры и служебные таблицы лежат в схеме `private`.** PostgREST её не публикует.
  `authenticated` получает `USAGE` на схему и `EXECUTE` только на хелперы, которые вызываются из политик.
- **`user_metadata` не влияет на права.** Пользователь может сам её поменять (`auth.updateUser`). Роль и компания
  берутся только из `profiles`. Триггер регистрации читает из метаданных только `name` и `company_name`
  (`raw_user_meta_data`) и `invite_code` (`raw_app_meta_data`: её задаёт только сервер, то есть Edge Function
  `join`, поэтому код нельзя погасить в обход её ограничения попыток). `role` и `company_id` из любых метаданных
  игнорируются.
- **RPC отдают JSON в формате контракта.** Список — массив объектов, один объект — объект. `Api*Repository`
  разбирают его готовыми `fromJson`.
- **Ошибки.** Функции бросают `raise sqlstate 'PT404' using hint = 'not_found'`, и PostgREST отвечает
  HTTP 404. Таблица «HTTP → `FailureCode`» из контракта остаётся в силе, а в `hint` лежит машинный код причины.

## Схема
| Таблица | Суть |
|---|---|
| `companies` | `name` |
| `profiles` | `id = auth.users.id`, `company_id`, `name`, `email`, `role`, `removed_at`. `Member.id` совпадает с `userId` |
| `projects` | `name`, `address`, `status`, `progress` (0–100), `company_id` |
| `project_members` | `project_id`, `user_id`; `foremanIds` и `workerIds` выводятся из роли в профиле |
| `invites` | `code` (6 символов из `inviteCodeAlphabet`), `role` (только foreman или worker), `expires_at` (+7 дней), `used_at`, `used_by` |
| `attachments` | владелец, `kind` (photo или voice), `bucket` и `path` в Storage, mime, bytes, width/height, `duration_ms`, `waveform` (40 × 0–100); `message_id` **или** `report_id`, `position`, `taken_at` |
| `reports` | `project_id`, `author_id`, `text`, `created_at` |
| `chats` | `type`, `project_id` (уникальный), `direct_key` (пара id, порядок не важен), `updated_at` |
| `chat_members` | `chat_id`, `user_id`, `last_read_seq`, `removed_at` (отметка прочтения сохраняется, если человека вернут в объект) |
| `messages` | `id uuid`, `seq` (identity, для страниц `before` и `after`), `kind`, `text`, `system_event`, `subject_user_id`, `report_id`; `(sender_id, client_id)` уникальна. У системных `sender_id is null`, в JSON — `"system"` |
| `message_listens` | `message_id`, `user_id` |
| `private.rate_limit_hits` | ключ и время; `private.hit_rate_limit(key, max, window)` |

**Видимость:**
- директор видит все объекты компании, прораб и строитель — только те, где они в `project_members`;
- отчёты, фото и чаты объекта видны тем, кому виден объект;
- чат виден активным участникам, личный — обоим;
- удалённый из компании (`removed_at`) не видит ничего, а в списках коллег его нет.

**Триггеры:**
- `auth.users` insert создаёт профиль: по `company_name` — новую компанию с директором; по `invite_code` —
  участника с ролью и компанией из кода, а код гасится атомарно; иначе ошибка, и пользователь не создаётся;
- объект создаётся вместе с чатом, в котором сразу все директора;
- изменения `project_members` и удаление профиля синхронизируют `chat_members` и пишут системные сообщения
  `memberAdded` / `memberRemoved`;
- сообщения, прочтения, прослушивания и изменения состава рассылают события Realtime.

## RPC и эндпоинты контракта
| Контракт | Supabase |
|---|---|
| login / logout / restore | GoTrue: `signInWithPassword`, `signOut`, обновление сессии; профиль — `get_me()` |
| register | `signUp` с `data: {name, company_name}` → триггер создаёт компанию и директора; затем `get_me()` |
| join | Edge Function `join` |
| `GET /projects`, `/:id` | `get_projects()`, `get_project(p_id)` |
| `POST /projects` | `create_project(p_name, p_address)` |
| `PUT /projects/:id` | `update_project(p_id, p_name?, p_address?, p_status?, p_progress?, p_foreman_ids?, p_worker_ids?)`. `null` означает «не менять», так что это частичное обновление |
| `POST/DELETE /projects/:id/foremen` | `assign_foreman(p_project_id, p_foreman_id)`, `remove_foreman(...)` |
| `GET /team/members?query=&role=` | `get_members(p_query?, p_role?)`. Правила `matchName` перенесены в `private.fold_name()` и `private.latin_to_cyrillic()` |
| `POST /team/invite` | `create_invite(p_role)` |
| `DELETE /team/members/:id` | Edge Function `remove-member` → служебная RPC `remove_member(p_actor_id, p_member_id)` + admin API |
| `GET /reports`, `/:id` | `get_reports(p_project_id?)`, `get_report(p_id)` |
| `POST /reports` | `submit_report(p_project_id, p_text, p_photos)`, где `p_photos` — `[{attachmentId, takenAt}]`, до 5 |
| `POST /uploads` | `create_upload(p_content_type, p_bytes, p_width?, p_height?, p_duration_ms?, p_waveform?)` → `{attachmentId, bucket, path}` |
| `GET /chats` | `get_chats()` |
| `GET /chats/:id/messages` | `get_messages(p_chat_id, p_before?, p_after?, p_limit?)` → `{messages, truncated}` |
| `POST /chats/:id/messages` | `send_message(p_chat_id, p_client_id, p_kind, p_text?, p_attachment_ids?)`; повтор с тем же `clientId` возвращает то же сообщение |
| `POST /chats/direct` | `get_or_create_direct(p_user_id)` |
| `POST …/read`, `…/listened` | `mark_read(p_chat_id, p_up_to)`, `mark_listened(p_chat_id, p_message_id)` |

HTTP-статусы 200/201 у RPC не различаются: PostgREST отвечает 200. Повтор отправки клиенту отличать не нужно.

## Авторизация
- **Регистрация** — обычный `signUp` (`data: {name, company_name}`). Если триггер отклонил вставку, GoTrue
  отвечает ошибкой: 400 с нашим `hint` или 500 «Database error saving new user». Имя и название компании клиент
  проверяет заранее.
- **Триггер регистрации отложен до `COMMIT`** (`constraint trigger … initially deferred`). `admin.createUser`
  вставляет пользователя без `app_metadata` и дописывает её вторым запросом той же транзакции, поэтому обычный
  `AFTER INSERT` не видел `invite_code`. Отложенный триггер перечитывает строку при `COMMIT`, а его исключение
  по-прежнему откатывает всю регистрацию. В pgTAP `tests.create_user` повторяет этот порядок.
- **Edge Function `join`** (`verify_jwt = false`):
  1. Ограничивает попытки: 10 в минуту с IP и с устройства (`X-Device-Id`). Сверх — 429 и `Retry-After: 60`.
     IP берётся из `cf-connecting-ip`, иначе из **последнего** адреса `X-Forwarded-For`: первый подставляет
     сам клиент. Смоук-тест проверяет, что выдуманный `X-Forwarded-For` лимит не сбрасывает.
  2. Вызывает `admin.createUser` с `email_confirm`, `user_metadata: {name}`, `app_metadata: {invite_code}`.
     GoTrue проверяет email раньше триггера, поэтому занятый email даёт 409, а код не тратится.
  3. Триггер гасит код одним `UPDATE … WHERE used_at IS NULL AND expires_at > now() RETURNING`. Если код
     не подошёл, триггер бросает исключение, и пользователь не создаётся. Функция тогда отвечает 404.
     Из двух одновременных запросов с одним кодом успешен один.
  4. Входит под новым пользователем и отвечает `201 {session, user, company}`.
- **Edge Function `remove-member`** (JWT директора, тело `{memberId}`):
  1. Проверяет токен (`auth.getUser`) и вызывает служебную RPC `remove_member(p_actor_id, p_member_id)`:
     проверка, что вызывающий — директор, `removed_at`, чистка `project_members` и чатов, системные сообщения —
     одной транзакцией. RPC доступна только `service_role`: если бы клиент мог вызвать её сам, удаление прошло бы
     без блокировки.
  2. Через admin API блокирует пользователя (`ban_duration`). У GoTrue нет admin-метода «выйти со всех устройств»
     по id пользователя: `admin.signOut` принимает JWT самого пользователя. Но заблокированному GoTrue не обновляет
     сессию (`Invalid Refresh Token: User Banned`) и не даёт войти (`user_banned`), а это и есть выход со всех
     устройств. Через ≤ 15 минут истекает и access-токен. Проверено смоук-тестом.
  3. Повтор после сбоя на шаге 2: RPC отвечает `already_removed`, функция ещё раз ставит блокировку и отвечает
     404, как требует контракт.
- **Удалённый участник до истечения access-токена** получает от RPC 403 с `hint: "account_removed"`. Прямые
  чтения таблиц под RLS возвращают ему пустой результат.

### Для этапа подключения клиента
- **403 с `hint` `account_removed` или `no_profile` клиент считает `sessionExpired`** и разлогинивает пользователя,
  а не показывает `forbidden`. Остальные 403 — `forbidden`.
- Вход заблокированного: GoTrue отвечает 400 `user_banned`, клиент показывает `invalidCredentials`.
- Ссылки на файлы: RPC отдают `bucket` и `path` вложения, а клиент сам подписывает их одним
  `createSignedUrls(paths, 3600)`. Кэш картинок — по `attachmentId`.
- Загрузка: `create_upload`, затем `POST /storage/v1/object/<bucket>/<path>` с JWT пользователя (Dio, прогресс
  по `onSendProgress`). Перезаписи нет: политика `update` на `storage.objects` не задана.
- Реальное время: приватный канал Realtime `user:<id>` (`RealtimeChannelConfig(private: true)`), события
  `message.created`, `message.status`, `message.listened`, `chat.updated`, `chat.removed` с телом из контракта.
- `kUseMockData` через `--dart-define`.

## Storage
- **Бакеты** (оба закрытые, создаются миграцией):
  - `photos` — до 10 МБ, `image/jpeg`, `image/png`, `image/webp`;
  - `voice` — до 2 МБ, `audio/mp4`.
- **Путь:** `{company_id}/{user_id}/{attachment_id}.{jpg|png|webp|m4a}`.
- **Политики `storage.objects`:**
  - `insert` — только по своему неприкреплённому вложению с таким путём;
  - `select` — владельцу и тем, кто видит сообщение или отчёт;
  - `update` и `delete` не заданы.
- «Загружено до конца» = объект есть в `storage.objects`. Это проверяется при прикреплении к сообщению или отчёту.

## Реальное время
Realtime Broadcast из базы: триггеры вызывают `realtime.send(payload, event, 'user:<id>', true)`. Политика
на `realtime.messages` пускает пользователя только в свой канал `user:<id>`. Это та же модель «одна очередь
на пользователя», что у STOMP в контракте, и то же тело событий. Переподключение работает как в контракте:
`get_chats()` и `get_messages(after=…)`.

## Ограничения частоты
`private.hit_rate_limit`: `join` — 10 в минуту на IP и устройство, `create_upload` — 60 в минуту
на пользователя, `send_message` — 30 в минуту на пользователя. Сверх лимита — 429.

## Отклонения от контракта (MVP)
- Сервер не проверяет содержимое файлов: тип по байтам, повторную вырезку EXIF, длительность голосового.
  Миниатюр нет: Image Transformations есть только на платном плане. Сервер доверяет клиентскому сжатию, тип
  и размер ограничивает бакет. `thumbnailUrl` клиент берёт равным `url`.
- Неприкреплённые вложения через сутки не удаляются. Позже это сделают pg_cron и Edge Function: файлы удаляются
  только через Storage API, а не через `DELETE` из `storage.objects`.
- Лимит по IP есть только у `join`. Остальные лимиты считаются по пользователю.
- Пути — `/rest/v1/rpc/<функция>` вместо REST-путей контракта. Вместо STOMP — Supabase Realtime.

## Этапы
1. Каркас: схемы, enum'ы, `companies`, `profiles`, триггер регистрации, хелперы, права, `get_me`, хелперы pgTAP.
2. Объекты и составы, частичный `update_project`.
3. Команда: приглашения, `join`, `remove_member` и `remove-member`, поиск, ограничения частоты.
4. Вложения, Storage, отчёты.
5. Чаты: составы, системные сообщения, отправка, история, прочтение и «прослушано», личные чаты.
6. Realtime.
7. `seed.sql` — демо-данные как в Fake.
8. Документация.

Клиент (`Api*Repository` поверх `supabase_flutter`) — отдельный план после бэкенда.

## Локальный запуск
Нужны Docker Desktop (запущен) и Node.js. Команды выполняются из корня репозитория.

```bash
npx supabase@2.122.0 start      # первый раз скачивает образы, несколько минут
npx supabase@2.122.0 db reset   # пересоздать базу: миграции + seed.sql
npx supabase@2.122.0 test db    # тесты pgTAP из supabase/tests/database
node supabase/tests/edge/smoke.mjs   # Edge Functions по HTTP на запущенном стеке
npx supabase@2.122.0 stop       # остановить
```
`start` печатает адреса и ключи: API `http://127.0.0.1:54321`, Studio `http://127.0.0.1:54323`.
