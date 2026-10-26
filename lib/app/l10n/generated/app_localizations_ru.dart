// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'BuildFlow';

  @override
  String get loginTitle => 'Вход';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get fullName => 'Имя и фамилия';

  @override
  String get companyName => 'Название компании';

  @override
  String get loginButton => 'Войти';

  @override
  String get registerButton => 'Создать аккаунт';

  @override
  String get noAccount => 'Нет аккаунта?';

  @override
  String get hasAccount => 'Уже есть аккаунт?';

  @override
  String get createCompany => 'Создать компанию';

  @override
  String get emailHint => 'example@mail.com';

  @override
  String get passwordHint => 'Минимум 6 символов';

  @override
  String get validationEmailRequired => 'Введите электронную почту';

  @override
  String get validationEmailInvalid => 'Некорректный адрес почты';

  @override
  String get validationPasswordRequired => 'Введите пароль';

  @override
  String get validationPasswordShort => 'Минимум 6 символов';

  @override
  String get validationNameRequired => 'Введите имя';

  @override
  String get validationCompanyRequired => 'Введите название компании';

  @override
  String get loginError => 'Неверный email или пароль';

  @override
  String get registerError => 'Ошибка регистрации';

  @override
  String get logoutConfirm => 'Вы уверены, что хотите выйти?';

  @override
  String get navProjects => 'Объекты';

  @override
  String get navTeam => 'Команда';

  @override
  String get navReports => 'Отчёты';

  @override
  String get navNewReport => 'Отчёт';

  @override
  String get navProfile => 'Профиль';

  @override
  String get projectsTitle => 'Строительные объекты';

  @override
  String get newProject => 'Новый объект';

  @override
  String get editProject => 'Редактировать';

  @override
  String get projectName => 'Название';

  @override
  String get projectNameHint => 'ЖК «Ала-Тоо»';

  @override
  String get projectAddress => 'Адрес';

  @override
  String get projectAddressHint => 'ул. Боконбаева, 123';

  @override
  String get projectStatus => 'Статус';

  @override
  String get statusActive => 'Активный';

  @override
  String get statusPaused => 'На паузе';

  @override
  String get statusFinished => 'Завершён';

  @override
  String get noProjects => 'Нет объектов';

  @override
  String get noProjectsHint => 'Добавьте свой первый строительный объект';

  @override
  String get projectSaved => 'Объект сохранён';

  @override
  String get assignedForemen => 'Назначенные прорабы';

  @override
  String get validationProjectName => 'Введите название объекта';

  @override
  String get validationProjectAddress => 'Введите адрес';

  @override
  String get teamTitle => 'Команда';

  @override
  String get inviteForeman => 'Пригласить прораба';

  @override
  String get inviteCodeTitle => 'Код приглашения';

  @override
  String get inviteCodeHint => 'Отправьте этот код прорабу';

  @override
  String get copyCode => 'Скопировать';

  @override
  String get shareCode => 'Поделиться';

  @override
  String get codeCopied => 'Код скопирован';

  @override
  String get noTeamMembers => 'Нет участников';

  @override
  String get noTeamMembersHint => 'Пригласите прорабов в команду';

  @override
  String get assignToProject => 'Назначить на объект';

  @override
  String get removeFromProject => 'Убрать с объекта';

  @override
  String get reportsTitle => 'Отчёты';

  @override
  String get newReportTitle => 'Новый отчёт';

  @override
  String get selectProject => 'Выберите объект';

  @override
  String get addPhotos => 'Добавить фото';

  @override
  String get takePhoto => 'Камера';

  @override
  String get fromGallery => 'Галерея';

  @override
  String get reportDescription => 'Описание работ';

  @override
  String get reportDescriptionHint => 'Что было сделано сегодня?';

  @override
  String get sendReport => 'Отправить';

  @override
  String get sending => 'Отправка...';

  @override
  String get reportSent => 'Отчёт отправлен!';

  @override
  String get reportSentHint => 'Владелец увидит ваш отчёт';

  @override
  String get noReports => 'Нет отчётов';

  @override
  String get noReportsHint => 'Отчёты за этот объект появятся здесь';

  @override
  String get noReportToday => 'Нет отчёта';

  @override
  String get draft => 'Черновик';

  @override
  String get draftsTitle => 'Черновики';

  @override
  String get retryUpload => 'Повторить';

  @override
  String get deleteDraft => 'Удалить черновик';

  @override
  String photosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count фото',
      few: '$count фото',
      one: '1 фото',
    );
    return '$_temp0';
  }

  @override
  String get stepProject => 'Объект';

  @override
  String get stepPhotos => 'Фото';

  @override
  String get stepDescription => 'Описание';

  @override
  String get stepSend => 'Отправка';

  @override
  String get maxPhotos => 'Максимум 5 фото';

  @override
  String get photoRequired => 'Добавьте хотя бы 1 фото';

  @override
  String get descriptionRequired => 'Добавьте описание';

  @override
  String get todayLabel => 'Сегодня';

  @override
  String get yesterdayLabel => 'Вчера';

  @override
  String reportBy(String name) {
    return 'Отчёт от $name';
  }

  @override
  String photoOf(int current, int total) {
    return 'Фото $current из $total';
  }

  @override
  String get profileTitle => 'Профиль';

  @override
  String get roleOwner => 'Директор';

  @override
  String get roleForeman => 'Прораб';

  @override
  String get roleWorker => 'Строитель';

  @override
  String get darkTheme => 'Тёмная тема';

  @override
  String get logout => 'Выйти';

  @override
  String appVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Редактировать';

  @override
  String get close => 'Закрыть';

  @override
  String get done => 'Готово';

  @override
  String get next => 'Далее';

  @override
  String get back => 'Назад';

  @override
  String get loading => 'Загрузка...';

  @override
  String get errorGeneral => 'Что-то пошло не так';

  @override
  String get errorNetwork => 'Ошибка сети. Проверьте подключение';

  @override
  String get errorServer => 'Ошибка сервера';

  @override
  String get offlineBanner => 'Нет подключения к интернету';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get noMembers => 'Пока нет участников';

  @override
  String get addProject => 'Добавить объект';

  @override
  String get required => 'Обязательное поле';

  @override
  String get foremenCount => 'Прорабов';

  @override
  String get inviteCode => 'Код приглашения';

  @override
  String get copy => 'Копировать';

  @override
  String get reportText => 'Описание работ';

  @override
  String get reportTextHint => 'Опишите, что было сделано сегодня...';

  @override
  String get photos => 'Фотографии';

  @override
  String get addPhoto => 'Добавить фото';

  @override
  String get noActiveProjects => 'Нет активных объектов';

  @override
  String get selectProjectHint => 'Выберите объект';

  @override
  String get reportError => 'Не удалось отправить отчёт';

  @override
  String get newReport => 'Новый отчёт';

  @override
  String get reportDetailTitle => 'Отчёт';

  @override
  String get reportNotFound => 'Отчёт не найден';

  @override
  String get projectNotFound => 'Объект не найден';

  @override
  String get projectTeam => 'Команда объекта';

  @override
  String get projectReports => 'Отчёты по объекту';

  @override
  String get editTeam => 'Изменить состав';

  @override
  String get foremen => 'Прорабы';

  @override
  String get workers => 'Строители';

  @override
  String get nobodyAssigned => 'Никто не назначен';

  @override
  String get noReportsForProject => 'По этому объекту ещё нет отчётов';

  @override
  String get statusChanged => 'Статус изменён';

  @override
  String get teamSaved => 'Состав объекта сохранён';

  @override
  String get quickLogin => 'Быстрый вход (демо):';

  @override
  String get noAssignedProjects => 'Вас пока не назначили ни на один объект';

  @override
  String get workersCount => 'Строителей';

  @override
  String get reportsCount => 'Отчётов';

  @override
  String get actionFailed => 'Не удалось выполнить действие';
}
