import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// Application name
  ///
  /// In ru, this message translates to:
  /// **'BuildFlow'**
  String get appName;

  /// Login screen title
  ///
  /// In ru, this message translates to:
  /// **'Вход'**
  String get loginTitle;

  /// Registration screen title
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// Email field label
  ///
  /// In ru, this message translates to:
  /// **'Электронная почта'**
  String get email;

  /// Password field label
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get password;

  /// Full name field label
  ///
  /// In ru, this message translates to:
  /// **'Имя и фамилия'**
  String get fullName;

  /// Company name field label
  ///
  /// In ru, this message translates to:
  /// **'Название компании'**
  String get companyName;

  /// Login button text
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get loginButton;

  /// Register button text
  ///
  /// In ru, this message translates to:
  /// **'Создать аккаунт'**
  String get registerButton;

  /// Prompt to register
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта?'**
  String get noAccount;

  /// Prompt to login
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт?'**
  String get hasAccount;

  /// Create company subtitle
  ///
  /// In ru, this message translates to:
  /// **'Создать компанию'**
  String get createCompany;

  /// Email hint text
  ///
  /// In ru, this message translates to:
  /// **'example@mail.com'**
  String get emailHint;

  /// Password hint text
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get passwordHint;

  /// Email required validation
  ///
  /// In ru, this message translates to:
  /// **'Введите электронную почту'**
  String get validationEmailRequired;

  /// Email invalid validation
  ///
  /// In ru, this message translates to:
  /// **'Некорректный адрес почты'**
  String get validationEmailInvalid;

  /// Password required validation
  ///
  /// In ru, this message translates to:
  /// **'Введите пароль'**
  String get validationPasswordRequired;

  /// Password too short validation
  ///
  /// In ru, this message translates to:
  /// **'Минимум 6 символов'**
  String get validationPasswordShort;

  /// Name required validation
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get validationNameRequired;

  /// Company name required validation
  ///
  /// In ru, this message translates to:
  /// **'Введите название компании'**
  String get validationCompanyRequired;

  /// Login error message
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get loginError;

  /// Registration error message
  ///
  /// In ru, this message translates to:
  /// **'Ошибка регистрации'**
  String get registerError;

  /// Logout confirmation
  ///
  /// In ru, this message translates to:
  /// **'Вы уверены, что хотите выйти?'**
  String get logoutConfirm;

  /// Projects nav label
  ///
  /// In ru, this message translates to:
  /// **'Объекты'**
  String get navProjects;

  /// Team nav label
  ///
  /// In ru, this message translates to:
  /// **'Команда'**
  String get navTeam;

  /// Reports nav label
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get navReports;

  /// New report nav label
  ///
  /// In ru, this message translates to:
  /// **'Отчёт'**
  String get navNewReport;

  /// Profile nav label
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// Projects screen title
  ///
  /// In ru, this message translates to:
  /// **'Строительные объекты'**
  String get projectsTitle;

  /// New project button
  ///
  /// In ru, this message translates to:
  /// **'Новый объект'**
  String get newProject;

  /// Edit project button
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editProject;

  /// Project name field label
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get projectName;

  /// Project name hint
  ///
  /// In ru, this message translates to:
  /// **'ЖК «Ала-Тоо»'**
  String get projectNameHint;

  /// Project address field label
  ///
  /// In ru, this message translates to:
  /// **'Адрес'**
  String get projectAddress;

  /// Project address hint
  ///
  /// In ru, this message translates to:
  /// **'ул. Боконбаева, 123'**
  String get projectAddressHint;

  /// Project status label
  ///
  /// In ru, this message translates to:
  /// **'Статус'**
  String get projectStatus;

  /// Active project status
  ///
  /// In ru, this message translates to:
  /// **'Активный'**
  String get statusActive;

  /// Paused project status
  ///
  /// In ru, this message translates to:
  /// **'На паузе'**
  String get statusPaused;

  /// Finished project status
  ///
  /// In ru, this message translates to:
  /// **'Завершён'**
  String get statusFinished;

  /// No projects empty state title
  ///
  /// In ru, this message translates to:
  /// **'Нет объектов'**
  String get noProjects;

  /// No projects empty state hint
  ///
  /// In ru, this message translates to:
  /// **'Добавьте свой первый строительный объект'**
  String get noProjectsHint;

  /// Project saved snackbar
  ///
  /// In ru, this message translates to:
  /// **'Объект сохранён'**
  String get projectSaved;

  /// Assigned foremen section title
  ///
  /// In ru, this message translates to:
  /// **'Назначенные прорабы'**
  String get assignedForemen;

  /// Project name validation
  ///
  /// In ru, this message translates to:
  /// **'Введите название объекта'**
  String get validationProjectName;

  /// Project address validation
  ///
  /// In ru, this message translates to:
  /// **'Введите адрес'**
  String get validationProjectAddress;

  /// Team screen title
  ///
  /// In ru, this message translates to:
  /// **'Команда'**
  String get teamTitle;

  /// Invite foreman button
  ///
  /// In ru, this message translates to:
  /// **'Пригласить прораба'**
  String get inviteForeman;

  /// Invite code dialog title
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get inviteCodeTitle;

  /// Invite code dialog hint
  ///
  /// In ru, this message translates to:
  /// **'Отправьте этот код прорабу'**
  String get inviteCodeHint;

  /// Copy code button
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get copyCode;

  /// Share code button
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get shareCode;

  /// Code copied snackbar
  ///
  /// In ru, this message translates to:
  /// **'Код скопирован'**
  String get codeCopied;

  /// No team members empty state title
  ///
  /// In ru, this message translates to:
  /// **'Нет участников'**
  String get noTeamMembers;

  /// No team members empty state hint
  ///
  /// In ru, this message translates to:
  /// **'Пригласите прорабов в команду'**
  String get noTeamMembersHint;

  /// Assign to project button
  ///
  /// In ru, this message translates to:
  /// **'Назначить на объект'**
  String get assignToProject;

  /// Remove from project button
  ///
  /// In ru, this message translates to:
  /// **'Убрать с объекта'**
  String get removeFromProject;

  /// Reports screen title
  ///
  /// In ru, this message translates to:
  /// **'Отчёты'**
  String get reportsTitle;

  /// New report screen title
  ///
  /// In ru, this message translates to:
  /// **'Новый отчёт'**
  String get newReportTitle;

  /// Select project step label
  ///
  /// In ru, this message translates to:
  /// **'Выберите объект'**
  String get selectProject;

  /// Add photos button
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get addPhotos;

  /// Take photo button
  ///
  /// In ru, this message translates to:
  /// **'Камера'**
  String get takePhoto;

  /// From gallery button
  ///
  /// In ru, this message translates to:
  /// **'Галерея'**
  String get fromGallery;

  /// Report description field label
  ///
  /// In ru, this message translates to:
  /// **'Описание работ'**
  String get reportDescription;

  /// Report description hint
  ///
  /// In ru, this message translates to:
  /// **'Что было сделано сегодня?'**
  String get reportDescriptionHint;

  /// Send report button
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get sendReport;

  /// Sending state text
  ///
  /// In ru, this message translates to:
  /// **'Отправка...'**
  String get sending;

  /// Report sent success message
  ///
  /// In ru, this message translates to:
  /// **'Отчёт отправлен!'**
  String get reportSent;

  /// Report sent success hint
  ///
  /// In ru, this message translates to:
  /// **'Владелец увидит ваш отчёт'**
  String get reportSentHint;

  /// No reports empty state title
  ///
  /// In ru, this message translates to:
  /// **'Нет отчётов'**
  String get noReports;

  /// No reports empty state hint
  ///
  /// In ru, this message translates to:
  /// **'Отчёты за этот объект появятся здесь'**
  String get noReportsHint;

  /// No report today badge
  ///
  /// In ru, this message translates to:
  /// **'Нет отчёта'**
  String get noReportToday;

  /// Draft badge text
  ///
  /// In ru, this message translates to:
  /// **'Черновик'**
  String get draft;

  /// Drafts section title
  ///
  /// In ru, this message translates to:
  /// **'Черновики'**
  String get draftsTitle;

  /// Retry upload button
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retryUpload;

  /// Delete draft button
  ///
  /// In ru, this message translates to:
  /// **'Удалить черновик'**
  String get deleteDraft;

  /// Number of photos
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, =1{1 фото} few{{count} фото} other{{count} фото}}'**
  String photosCount(int count);

  /// Step 1 label
  ///
  /// In ru, this message translates to:
  /// **'Объект'**
  String get stepProject;

  /// Step 2 label
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get stepPhotos;

  /// Step 3 label
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get stepDescription;

  /// Step 4 label
  ///
  /// In ru, this message translates to:
  /// **'Отправка'**
  String get stepSend;

  /// Max photos hint
  ///
  /// In ru, this message translates to:
  /// **'Максимум 5 фото'**
  String get maxPhotos;

  /// Photo required validation
  ///
  /// In ru, this message translates to:
  /// **'Добавьте хотя бы 1 фото'**
  String get photoRequired;

  /// Description required validation
  ///
  /// In ru, this message translates to:
  /// **'Добавьте описание'**
  String get descriptionRequired;

  /// Today date label
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get todayLabel;

  /// Yesterday date label
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterdayLabel;

  /// Report author attribution
  ///
  /// In ru, this message translates to:
  /// **'Отчёт от {name}'**
  String reportBy(String name);

  /// Photo counter in gallery
  ///
  /// In ru, this message translates to:
  /// **'Фото {current} из {total}'**
  String photoOf(int current, int total);

  /// Profile screen title
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// Owner role label
  ///
  /// In ru, this message translates to:
  /// **'Директор'**
  String get roleOwner;

  /// Foreman role label
  ///
  /// In ru, this message translates to:
  /// **'Прораб'**
  String get roleForeman;

  /// Worker role label
  ///
  /// In ru, this message translates to:
  /// **'Строитель'**
  String get roleWorker;

  /// Dark theme toggle
  ///
  /// In ru, this message translates to:
  /// **'Тёмная тема'**
  String get darkTheme;

  /// Logout button
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// App version display
  ///
  /// In ru, this message translates to:
  /// **'Версия {version}'**
  String appVersion(String version);

  /// Retry button
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// Cancel button
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// Save button
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// Delete button
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// Edit button
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get edit;

  /// Close button
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// Done button
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// Next button
  ///
  /// In ru, this message translates to:
  /// **'Далее'**
  String get next;

  /// Back button
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// Loading state
  ///
  /// In ru, this message translates to:
  /// **'Загрузка...'**
  String get loading;

  /// General error message
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get errorGeneral;

  /// Network error message
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети. Проверьте подключение'**
  String get errorNetwork;

  /// Server error message
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сервера'**
  String get errorServer;

  /// Offline banner text
  ///
  /// In ru, this message translates to:
  /// **'Нет подключения к интернету'**
  String get offlineBanner;

  /// Confirm button
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// Yes button
  ///
  /// In ru, this message translates to:
  /// **'Да'**
  String get yes;

  /// No button
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get no;

  /// Today label for date grouping
  ///
  /// In ru, this message translates to:
  /// **'Сегодня'**
  String get today;

  /// Yesterday label for date grouping
  ///
  /// In ru, this message translates to:
  /// **'Вчера'**
  String get yesterday;

  /// Empty state for team list
  ///
  /// In ru, this message translates to:
  /// **'Пока нет участников'**
  String get noMembers;

  /// Add project button
  ///
  /// In ru, this message translates to:
  /// **'Добавить объект'**
  String get addProject;

  /// Required field validation
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get required;

  /// Foremen count label
  ///
  /// In ru, this message translates to:
  /// **'Прорабов'**
  String get foremenCount;

  /// Invite code title
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения'**
  String get inviteCode;

  /// Copy button tooltip
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get copy;

  /// Report text field label
  ///
  /// In ru, this message translates to:
  /// **'Описание работ'**
  String get reportText;

  /// Report text hint
  ///
  /// In ru, this message translates to:
  /// **'Опишите, что было сделано сегодня...'**
  String get reportTextHint;

  /// Photos section title
  ///
  /// In ru, this message translates to:
  /// **'Фотографии'**
  String get photos;

  /// Add photo button
  ///
  /// In ru, this message translates to:
  /// **'Добавить фото'**
  String get addPhoto;

  /// No active projects message
  ///
  /// In ru, this message translates to:
  /// **'Нет активных объектов'**
  String get noActiveProjects;

  /// Select project hint
  ///
  /// In ru, this message translates to:
  /// **'Выберите объект'**
  String get selectProjectHint;

  /// Report submission error
  ///
  /// In ru, this message translates to:
  /// **'Не удалось отправить отчёт'**
  String get reportError;

  /// New report screen title
  ///
  /// In ru, this message translates to:
  /// **'Новый отчёт'**
  String get newReport;

  /// Report detail screen title
  ///
  /// In ru, this message translates to:
  /// **'Отчёт'**
  String get reportDetailTitle;

  /// Report not found message
  ///
  /// In ru, this message translates to:
  /// **'Отчёт не найден'**
  String get reportNotFound;

  /// Project not found message
  ///
  /// In ru, this message translates to:
  /// **'Объект не найден'**
  String get projectNotFound;

  /// Project team section title
  ///
  /// In ru, this message translates to:
  /// **'Команда объекта'**
  String get projectTeam;

  /// Project reports section title
  ///
  /// In ru, this message translates to:
  /// **'Отчёты по объекту'**
  String get projectReports;

  /// Edit project team button
  ///
  /// In ru, this message translates to:
  /// **'Изменить состав'**
  String get editTeam;

  /// Foremen group title
  ///
  /// In ru, this message translates to:
  /// **'Прорабы'**
  String get foremen;

  /// Workers group title
  ///
  /// In ru, this message translates to:
  /// **'Строители'**
  String get workers;

  /// No members assigned to project
  ///
  /// In ru, this message translates to:
  /// **'Никто не назначен'**
  String get nobodyAssigned;

  /// No reports for project
  ///
  /// In ru, this message translates to:
  /// **'По этому объекту ещё нет отчётов'**
  String get noReportsForProject;

  /// Project status changed snackbar
  ///
  /// In ru, this message translates to:
  /// **'Статус изменён'**
  String get statusChanged;

  /// Project team saved snackbar
  ///
  /// In ru, this message translates to:
  /// **'Состав объекта сохранён'**
  String get teamSaved;

  /// Demo quick login title
  ///
  /// In ru, this message translates to:
  /// **'Быстрый вход (демо):'**
  String get quickLogin;

  /// No assigned projects hint
  ///
  /// In ru, this message translates to:
  /// **'Вас пока не назначили ни на один объект'**
  String get noAssignedProjects;

  /// Workers count label
  ///
  /// In ru, this message translates to:
  /// **'Строителей'**
  String get workersCount;

  /// Reports count label
  ///
  /// In ru, this message translates to:
  /// **'Отчётов'**
  String get reportsCount;

  /// Generic action failure snackbar
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выполнить действие'**
  String get actionFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
