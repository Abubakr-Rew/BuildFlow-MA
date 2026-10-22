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

Присоединение прораба по коду приглашения.

```json
// Request
{
  "email": "foreman@mail.kg",
  "password": "secret",
  "name": "Имя",
  "inviteCode": "ABC123"
}

// Response 201
{
  "token": "...",
  "user": { ... }
}

// Response 404
{ "error": "Неверный код приглашения" }
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
      "name": "ЖК \"Ала-Тоо Резиденс\"",
      "address": "ул. Токтогула 125, Бишкек",
      "status": "active",
      "companyId": "company-1",
      "foremanIds": ["user-foreman-1"]
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

Обновление объекта (только owner).

```json
// Request
{
  "name": "Обновлённое имя",
  "address": "Новый адрес",
  "status": "paused"
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

Генерация кода приглашения (только owner).

```json
// Response 201
{
  "invite": {
    "code": "ABC123",
    "companyId": "company-1",
    "createdAt": "2024-06-15T10:00:00Z",
    "expiresAt": "2024-06-22T10:00:00Z"
  }
}
```

### DELETE /team/members/:id

Удаление участника из компании (только owner).

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
      "projectName": "ЖК \"Ала-Тоо Резиденс\"",
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
| 500 | Ошибка сервера |

---

## Enums

### UserRole
- `owner` — владелец компании
- `foreman` — прораб

### ProjectStatus
- `active` — объект в работе
- `paused` — приостановлен
- `finished` — завершён
