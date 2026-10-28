# BuildFlow API Contract

> Этот документ описывает контракт REST API, на который рассчитаны `ApiXxxRepository`-скелеты.
> Пока бэкенд не готов, приложение работает на `FakeXxxRepository` с демо-данными.

## Base URL

```
https://api.buildflow.kg/v1
```

## Authentication

Все запросы (кроме login/register) требуют заголовок:

```
Authorization: Bearer <token>
```

---

## Auth

### POST /auth/login

```json
// Request
{
  "email": "owner@buildflow.kg",
  "password": "123456"
}

// Response 200
{
  "token": "eyJhbGciOiJI...",
  "user": {
    "id": "user-1",
    "email": "owner@buildflow.kg",
    "name": "Асан Бекович",
    "role": "owner",
    "companyId": "company-1"
  }
}

// Response 401
{ "error": "Неверный email или пароль" }
```

### POST /auth/register

```json
// Request
{
  "email": "new@company.kg",
  "password": "secret123",
  "name": "Имя Фамилия",
  "companyName": "Новая Компания"
}

// Response 201
{
  "token": "eyJhbGciOiJI...",
  "user": { ... },
  "company": {
    "id": "company-2",
    "name": "Новая Компания"
  }
}

// Response 409
{ "error": "Пользователь с таким email уже существует" }
```

### POST /auth/join

Присоединение прораба или строителя по коду приглашения (`POST /team/invite`).
Роль и компанию задаёт код, клиент их не передаёт.

- Клиент отправляет код нормализованным: без пробелов и дефисов, в верхнем регистре (`abc-234` → `ABC234`).
  Сервер сравнивает так же.
- Код одноразовый. Сервер помечает его использованным в той же транзакции, в которой создаёт пользователя
  и участника компании. После этого новый участник есть в `GET /team/members`.
- Неизвестный, уже использованный или истёкший (`expiresAt` в прошлом) код → 404. Различать эти случаи клиенту
  не нужно: пользователь в любом случае просит у директора новый код.
- Занятый email → 409. Сервер проверяет его до того, как погасить код, поэтому тот же код можно отправить
  ещё раз с другим email.
- **Погашение атомарное.** Проверка «код есть, не использован, не истёк» и пометка `isUsed` выполняются одной
  операцией, например `UPDATE invites SET used_at = now() WHERE code = ? AND used_at IS NULL AND expires_at > now()`
  с проверкой числа изменённых строк, или под блокировкой строки в транзакции. Пользователь и участник создаются
  в той же транзакции. Из двух одновременных запросов с одним кодом успешен только один (201), второй получает 404.
  Если создать пользователя не удалось (например, email заняли параллельно → 409), транзакция откатывается
  и код остаётся неиспользованным.
- **Ограничение попыток.** Коды короткие (31⁶ ≈ 890 млн вариантов), поэтому подбор надо ограничивать: не больше
  10 запросов в минуту с одного IP и с одного устройства (заголовок `X-Device-Id`). Считаются все запросы, а не только
  неудачные. При превышении сервер отвечает 429 с заголовком `Retry-After` (секунды) и запрос не выполняет. Клиент
  показывает `tooManyRequests` («Подождите минуту») и сам повторно не отправляет.

```json
// Request
{
  "email": "worker@mail.kg",
  "password": "secret",
  "name": "Имя",
  "inviteCode": "K7M2QX"
}

// Response 201
{
  "token": "...",
  "user": {
    "id": "user-7",
    "email": "worker@mail.kg",
    "name": "Имя",
    "role": "worker",
    "companyId": "company-1"
  },
  "company": { "id": "company-1", "name": "СтройБишкек" }
}

// Response 404
{ "error": "Неверный, использованный или истёкший код приглашения" }

// Response 409
{ "error": "Пользователь с таким email уже существует" }

// Response 429, заголовок Retry-After: 60
{ "error": "Слишком много попыток" }
```

### POST /auth/restore

Восстановление сессии по токену.

```
Authorization: Bearer <token>
```

```json
// Response 200
{ "user": { ... } }

// Response 401
{ "error": "Session expired" }
```

### POST /auth/logout

```
Authorization: Bearer <token>
```

```json
// Response 204 (no content)
```

---

## Projects

### GET /projects

Возвращает все объекты компании текущего пользователя.

```json
// Response 200
{
  "projects": [
    {
      "id": "project-1",
      "name": "ЖК «Ала-Тоо Резиденс»",
      "address": "ул. Токтогула 125, Бишкек",
      "status": "active",
      "companyId": "company-1",
      "foremanIds": ["user-foreman-1"],
      "workerIds": ["user-worker-1"],
      "progress": 65
    }
  ]
}
```

### GET /projects/:id

```json
// Response 200
{ "project": { ... } }

// Response 404
{ "error": "Объект не найден" }
```

### POST /projects

Создание нового объекта (только owner).

```json
// Request
{
  "name": "Новый объект",
  "address": "ул. Тестовая 1"
}

// Response 201
{ "project": { ... } }
```

### PUT /projects/:id

Обновление объекта (только owner). `progress` — готовность в процентах, целое 0–100; клиент шлёт значения с шагом 5, сервер принимает любое целое в диапазоне, иначе 422 → `validation`.

```json
// Request
{
  "name": "Обновлённое имя",
  "address": "Новый адрес",
  "status": "paused",
  "progress": 70
}

// Response 200
{ "project": { ... } }
```

### POST /projects/:id/foremen

Привязка прораба к объекту.

```json
// Request
{ "foremanId": "user-foreman-2" }

// Response 200
{ "project": { ... } }
```

### DELETE /projects/:id/foremen/:foremanId

Удаление прораба с объекта.

```json
// Response 200
{ "project": { ... } }
```

---

## Team

### GET /team/members

```json
// Response 200
{
  "members": [
    {
      "id": "member-1",
      "userId": "user-1",
      "name": "Асан Бекович",
      "email": "owner@buildflow.kg",
      "role": "owner",
      "companyId": "company-1",
      "assignedProjectIds": []
    }
  ]
}
```

### POST /team/invite

Генерация одноразового кода приглашения (только owner). Кто присоединится по коду (`POST /auth/join`),
получит указанную роль в компании директора.

- `role` — только `foreman` или `worker`. На `owner` или любое другое значение сервер отвечает 400 (`validation`).
- Код: 6 символов из `ABCDEFGHJKMNPQRSTUVWXYZ23456789`. Похожих символов (0/O, 1/I/L) в нём нет: коды диктуют
  по телефону и перепечатывают из сообщений.
- Срок действия — 7 дней (`expiresAt`).

```json
// Request
{ "role": "worker" }

// Response 201
{
  "invite": {
    "code": "K7M2QX",
    "companyId": "company-1",
    "role": "worker",
    "createdAt": "2024-06-15T10:00:00Z",
    "expiresAt": "2024-06-22T10:00:00Z",
    "isUsed": false
  }
}
```

### DELETE /team/members/:id

Удаление участника из компании (только owner).

Сервер в той же операции убирает участника из `foremanIds` / `workerIds` всех объектов компании.
Клиент после 204 только перезагружает объекты и участников, отдельных запросов к объектам не шлёт.
Повторный `DELETE` уже удалённого участника → 404 (`notFound`).

Удалённый участник больше не может войти: `POST /auth/login` отвечает ему 401 (`invalidCredentials`). Его выданные
токены сервер отзывает, и следующий запрос с таким токеном, включая `POST /auth/restore`, получает 401
(`sessionExpired`). Клиент в ответ разлогинивает пользователя. В Fake-режиме это не реализовано: удалённый участник
по-прежнему входит.

```json
// Response 204 (no content)
```

---

## Reports

### GET /reports

Все отчёты компании, отсортированные по дате (новые первыми).

```json
// Response 200
{
  "reports": [
    {
      "id": "report-1",
      "projectId": "project-1",
      "projectName": "ЖК «Ала-Тоо Резиденс»",
      "authorId": "user-foreman-1",
      "authorName": "Бакыт Касымов",
      "text": "Залили фундамент блока Б...",
      "photos": [
        {
          "id": "photo-1",
          "url": "https://storage.buildflow.kg/photos/abc.jpg",
          "thumbnailUrl": "https://storage.buildflow.kg/thumbs/abc.jpg"
        }
      ],
      "createdAt": "2024-06-15T14:30:00Z"
    }
  ]
}
```

### GET /reports?projectId=:id

Фильтрация отчётов по объекту.

### GET /reports/:id

```json
// Response 200
{ "report": { ... } }

// Response 404
{ "error": "Отчёт не найден" }
```

### POST /reports

Отправка нового отчёта (только foreman). Multipart/form-data.

```
Content-Type: multipart/form-data

Fields:
  projectId: "project-1"
  text: "Описание выполненных работ..."

Files:
  photos[]: <file1.jpg>
  photos[]: <file2.jpg>
```

```json
// Response 201
{ "report": { ... } }
```

---

## Error Format

Все ошибки возвращаются в формате:

```json
{
  "error": "Человекочитаемое описание ошибки"
}
```

### HTTP коды

| Код | Значение |
|-----|----------|
| 200 | Успех |
| 201 | Создано |
| 204 | Без содержимого |
| 400 | Ошибка валидации |
| 401 | Не авторизован |
| 403 | Нет доступа |
| 404 | Не найдено |
| 409 | Конфликт (дублирование) |
| 429 | Слишком много запросов (`Retry-After`) |
| 500 | Ошибка сервера |

### Коды ошибок клиента

Текст из `error` клиент пользователю не показывает: он попадает только в `Failure.message` для логов.
Что увидит пользователь, решает `FailureCode` (`lib/core/error/failures.dart`). `Api*Repository` выводит его
из HTTP-статуса и эндпоинта:

| Ответ | `FailureCode` |
|-------|---------------|
| Нет соединения, обрыв, ошибка DNS | `network` |
| Таймаут запроса | `timeout` |
| 400 | `validation` |
| 401 на `POST /auth/login` | `invalidCredentials` |
| 401 на остальных запросах | `sessionExpired` |
| 403 | `forbidden` |
| 404 на `POST /auth/join` (код неизвестен, использован или истёк) | `invalidInviteCode` |
| 404 на остальных запросах | `notFound` |
| 409 (сейчас только `POST /auth/register` и `POST /auth/join`) | `emailTaken` |
| 429 (сейчас только `POST /auth/join`) | `tooManyRequests` |
| 5xx | `server` |
| Всё остальное | `unknown` |

Если на одном эндпоинте понадобится различать несколько ошибок с одинаковым статусом, сервер должен добавить
в ответ машиночитаемое поле `code` (например, `{"error": "...", "code": "email_taken"}`), а клиент — новое значение
`FailureCode`.

---

## Enums

### UserRole
- `owner` — владелец компании
- `foreman` — прораб
- `worker` — строитель

### ProjectStatus
- `active` — объект в работе
- `paused` — приостановлен
- `finished` — сдан (завершён)
