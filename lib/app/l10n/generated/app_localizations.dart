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

  /// Tagline under the app name on the splash screen
  ///
  /// In ru, this message translates to:
  /// **'Фото-отчёты со стройки'**
  String get appTagline;

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

  /// Login screen link to the join screen
  ///
  /// In ru, this message translates to:
  /// **'Есть код приглашения?'**
  String get haveInviteCode;

  /// Join screen title
  ///
  /// In ru, this message translates to:
  /// **'Вход по приглашению'**
  String get joinTitle;

  /// Join screen subtitle: role and company come from the code
  ///
  /// In ru, this message translates to:
  /// **'Роль и компанию задаёт код от директора'**
  String get joinSubtitle;

  /// Invite code field hint on the join screen
  ///
  /// In ru, this message translates to:
  /// **'6 символов, например K7M2QX'**
  String get inviteCodeFieldHint;

  /// Join screen submit button
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться'**
  String get joinButton;

  /// Validation: invite code is empty
  ///
  /// In ru, this message translates to:
  /// **'Введите код приглашения'**
  String get validationInviteCodeRequired;

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
  /// **'Объекты'**
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
  /// **'В работе'**
  String get statusActive;

  /// Paused project status
  ///
  /// In ru, this message translates to:
  /// **'На паузе'**
  String get statusPaused;

  /// Finished project status
  ///
  /// In ru, this message translates to:
  /// **'Сдан'**
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

  /// Invite code sheet hint: lifetime and single use
  ///
  /// In ru, this message translates to:
  /// **'Код действует 7 дней и подходит для одного входа'**
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

  /// Snackbar when the camera or gallery fails
  ///
  /// In ru, this message translates to:
  /// **'Не удалось выбрать фото'**
  String get photoPickError;

  /// Snackbar when the user has refused camera permission
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к камере. Его можно включить в настройках приложения'**
  String get cameraAccessDenied;

  /// Snackbar when the user has refused photo library permission (iOS)
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к фото. Его можно включить в настройках приложения'**
  String get photoAccessDenied;

  /// Snackbar action that opens the app's system settings
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get openSettings;

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
  /// **'Отправить отчёт'**
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

  /// FailureCode.network: no internet connection
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети. Проверьте подключение'**
  String get errorNetwork;

  /// FailureCode.timeout: the request took too long
  ///
  /// In ru, this message translates to:
  /// **'Сервер долго не отвечает. Попробуйте ещё раз'**
  String get errorTimeout;

  /// FailureCode.server: server error or unreachable
  ///
  /// In ru, this message translates to:
  /// **'Сервер недоступен. Попробуйте позже'**
  String get errorServer;

  /// FailureCode.invalidCredentials: wrong email or password
  ///
  /// In ru, this message translates to:
  /// **'Неверный email или пароль'**
  String get errorInvalidCredentials;

  /// FailureCode.emailTaken: email already registered
  ///
  /// In ru, this message translates to:
  /// **'Пользователь с таким email уже существует'**
  String get errorEmailTaken;

  /// FailureCode.invalidInviteCode: unknown, used or expired invite code
  ///
  /// In ru, this message translates to:
  /// **'Код приглашения неверный, уже использован или истёк'**
  String get errorInvalidInviteCode;

  /// FailureCode.sessionExpired: the user must log in again
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова'**
  String get errorSessionExpired;

  /// FailureCode.accountDisabled: the user was removed from the company and can no longer sign in
  ///
  /// In ru, this message translates to:
  /// **'Доступ закрыт. Обратитесь к директору компании'**
  String get errorAccountDisabled;

  /// FailureCode.forbidden: the role does not allow the action
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия'**
  String get errorForbidden;

  /// FailureCode.notFound: project, report or member does not exist
  ///
  /// In ru, this message translates to:
  /// **'Данные не найдены. Возможно, их удалили'**
  String get errorNotFound;

  /// FailureCode.validation: the server rejected the data
  ///
  /// In ru, this message translates to:
  /// **'Проверьте введённые данные'**
  String get errorValidation;

  /// FailureCode.tooManyRequests: rate limit hit (429)
  ///
  /// In ru, this message translates to:
  /// **'Слишком много попыток. Подождите минуту и попробуйте снова'**
  String get errorTooManyRequests;

  /// FailureCode.photoProcessing: a picked photo couldn't be compressed on the device
  ///
  /// In ru, this message translates to:
  /// **'Не удалось обработать фото. Попробуйте ещё раз или выберите другое'**
  String get errorPhotoProcessing;

  /// FailureCode.unknown and unexpected exceptions
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так'**
  String get errorUnknown;

  /// Title of the screen shown instead of the app when the build has no server address
  ///
  /// In ru, this message translates to:
  /// **'Сборка настроена неверно'**
  String get configErrorTitle;

  /// Text above the technical details on the build configuration error screen
  ///
  /// In ru, this message translates to:
  /// **'Соберите приложение заново с адресом сервера. Подробности для разработчика:'**
  String get configErrorHint;

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

  /// Report submission error; reason is l10n.failureMessage(failure)
  ///
  /// In ru, this message translates to:
  /// **'Отчёт не отправлен. {reason}'**
  String reportError(String reason);

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

  /// Invite member button
  ///
  /// In ru, this message translates to:
  /// **'Пригласить'**
  String get inviteMember;

  /// Invite role picker title
  ///
  /// In ru, this message translates to:
  /// **'Кого пригласить?'**
  String get inviteWho;

  /// Remove member action
  ///
  /// In ru, this message translates to:
  /// **'Удалить из команды'**
  String get removeMember;

  /// Remove member confirmation
  ///
  /// In ru, this message translates to:
  /// **'Удалить {name} из команды?'**
  String removeMemberConfirm(String name);

  /// Member removed snackbar
  ///
  /// In ru, this message translates to:
  /// **'Участник удалён'**
  String get memberRemoved;

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

  /// Greeting above the projects title, 5:00–11:59
  ///
  /// In ru, this message translates to:
  /// **'Доброе утро, {name}'**
  String greetingMorning(String name);

  /// Greeting above the projects title, 12:00–17:59
  ///
  /// In ru, this message translates to:
  /// **'Добрый день, {name}'**
  String greetingDay(String name);

  /// Greeting above the projects title, 18:00–23:59
  ///
  /// In ru, this message translates to:
  /// **'Добрый вечер, {name}'**
  String greetingEvening(String name);

  /// Greeting above the projects title, 0:00–4:59
  ///
  /// In ru, this message translates to:
  /// **'Доброй ночи, {name}'**
  String greetingNight(String name);

  /// Day summary: active projects with a report today out of all active
  ///
  /// In ru, this message translates to:
  /// **'Отчётов сдано'**
  String get summaryReportsSent;

  /// Day summary: photos in today's reports
  ///
  /// In ru, this message translates to:
  /// **'Новых фото'**
  String get summaryNewPhotos;

  /// Day summary: active projects
  ///
  /// In ru, this message translates to:
  /// **'Объектов в работе'**
  String get summaryActiveProjects;

  /// Day summary badge: active projects without a report today
  ///
  /// In ru, this message translates to:
  /// **'{count} без отчёта'**
  String summaryWithoutReport(int count);

  /// Project filter chip: all statuses
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get filterAll;

  /// Project readiness label
  ///
  /// In ru, this message translates to:
  /// **'Готовность'**
  String get progressLabel;

  /// A percentage
  ///
  /// In ru, this message translates to:
  /// **'{value}%'**
  String percentValue(int value);

  /// Project card: time of today's latest report
  ///
  /// In ru, this message translates to:
  /// **'Отчёт в {time}'**
  String reportAt(String time);

  /// Project card: active project without a report today
  ///
  /// In ru, this message translates to:
  /// **'Нет отчёта за сегодня'**
  String get noReportForToday;

  /// Project menu item and dialog title
  ///
  /// In ru, this message translates to:
  /// **'Изменить готовность'**
  String get changeProgress;

  /// Snackbar after the readiness is saved
  ///
  /// In ru, this message translates to:
  /// **'Готовность сохранена'**
  String get progressSaved;

  /// Tooltip of the overflow menu button
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// New report screen title
  ///
  /// In ru, this message translates to:
  /// **'Отчёт за сегодня'**
  String get reportForToday;

  /// Photos added out of the maximum
  ///
  /// In ru, this message translates to:
  /// **'{count} из {total}'**
  String photoCounter(int count, int total);

  /// Opens the camera on the new report screen
  ///
  /// In ru, this message translates to:
  /// **'Сделать фото'**
  String get takePhotoButton;

  /// Tooltip of the remove button on a photo
  ///
  /// In ru, this message translates to:
  /// **'Удалить фото'**
  String get removePhoto;

  /// Report text field label
  ///
  /// In ru, this message translates to:
  /// **'Что сделано'**
  String get reportWhatDone;

  /// Quick template chip appended to the report text
  ///
  /// In ru, this message translates to:
  /// **'Бетон'**
  String get templateConcrete;

  /// Quick template chip appended to the report text
  ///
  /// In ru, this message translates to:
  /// **'Армирование'**
  String get templateRebar;

  /// Quick template chip appended to the report text
  ///
  /// In ru, this message translates to:
  /// **'Кладка'**
  String get templateMasonry;

  /// Quick template chip appended to the report text
  ///
  /// In ru, this message translates to:
  /// **'Нужны материалы'**
  String get templateMaterials;

  /// People search screen title and the tooltip of its entry button
  ///
  /// In ru, this message translates to:
  /// **'Поиск людей'**
  String get searchPeople;

  /// People search field label
  ///
  /// In ru, this message translates to:
  /// **'Имя или фамилия'**
  String get searchPeopleField;

  /// Tooltip of the clear button in a search field
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clearSearch;

  /// Section of recently opened people on the empty search screen
  ///
  /// In ru, this message translates to:
  /// **'Недавние'**
  String get recentPeople;

  /// People search before typing, when nobody was opened yet
  ///
  /// In ru, this message translates to:
  /// **'Найдите коллегу'**
  String get searchPeopleStart;

  /// Hint under searchPeopleStart
  ///
  /// In ru, this message translates to:
  /// **'Введите имя или фамилию, хватит первых букв'**
  String get searchPeopleStartHint;

  /// People search found nobody
  ///
  /// In ru, this message translates to:
  /// **'Никого не нашли'**
  String get nobodyFound;

  /// Hint under nobodyFound
  ///
  /// In ru, this message translates to:
  /// **'Проверьте написание имени или фамилии'**
  String get nobodyFoundHint;

  /// Footer of the people search screen, next to a lock icon
  ///
  /// In ru, this message translates to:
  /// **'Поиск показывает только сотрудников вашей компании'**
  String get searchCompanyOnly;

  /// Projects section in the person sheet
  ///
  /// In ru, this message translates to:
  /// **'Объекты'**
  String get memberProjects;

  /// Person sheet for a foreman or worker: the person works on none of the viewer's projects
  ///
  /// In ru, this message translates to:
  /// **'Нет общих объектов'**
  String get noSharedProjects;

  /// Person sheet for the director: the person works on no project
  ///
  /// In ru, this message translates to:
  /// **'Не назначен на объекты'**
  String get memberNotAssigned;

  /// Bottom navigation: chats tab
  ///
  /// In ru, this message translates to:
  /// **'Чаты'**
  String get navChats;

  /// Bottom navigation for the foreman: the list of reports
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get navHistory;

  /// Title of the foreman's report list tab
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get reportHistoryTitle;

  /// Chat list screen title
  ///
  /// In ru, this message translates to:
  /// **'Чаты'**
  String get chatsTitle;

  /// Chat list search field label
  ///
  /// In ru, this message translates to:
  /// **'Объект или имя'**
  String get searchChats;

  /// Chat list filter chip: every chat
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get chatFilterAll;

  /// Chat list filter chip: project chats
  ///
  /// In ru, this message translates to:
  /// **'Объекты'**
  String get chatFilterProjects;

  /// Chat list filter chip: direct chats
  ///
  /// In ru, this message translates to:
  /// **'Личные'**
  String get chatFilterDirect;

  /// Empty chat list
  ///
  /// In ru, this message translates to:
  /// **'Чатов пока нет'**
  String get noChats;

  /// Hint under noChats
  ///
  /// In ru, this message translates to:
  /// **'Здесь будут чаты ваших объектов и личные переписки'**
  String get noChatsHint;

  /// Chat search or filter found nothing
  ///
  /// In ru, this message translates to:
  /// **'Ничего не нашли'**
  String get noChatsFound;

  /// Hint under noChatsFound
  ///
  /// In ru, this message translates to:
  /// **'Проверьте название объекта или имя'**
  String get noChatsFoundHint;

  /// Tooltip of the chat list button that opens people search
  ///
  /// In ru, this message translates to:
  /// **'Написать коллеге'**
  String get newDirectChat;

  /// Chat list preview and empty chat title: no messages yet
  ///
  /// In ru, this message translates to:
  /// **'Сообщений пока нет'**
  String get chatNoMessages;

  /// Hint in an empty chat
  ///
  /// In ru, this message translates to:
  /// **'Напишите первое сообщение'**
  String get chatEmptyHint;

  /// Author of the user's own message in a chat preview: «Вы: текст»
  ///
  /// In ru, this message translates to:
  /// **'Вы'**
  String get you;

  /// Subtitle of a project chat
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} участник} few{{count} участника} many{{count} участников} other{{count} участника}}'**
  String chatParticipants(int count);

  /// Hint of the message field
  ///
  /// In ru, this message translates to:
  /// **'Сообщение'**
  String get messageHint;

  /// Tooltip of the send button in a chat
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get sendMessage;

  /// Status of an own message, for screen readers
  ///
  /// In ru, this message translates to:
  /// **'Отправляется'**
  String get messageSending;

  /// Status of an own message, for screen readers
  ///
  /// In ru, this message translates to:
  /// **'Отправлено'**
  String get messageSent;

  /// Status of an own message, for screen readers
  ///
  /// In ru, this message translates to:
  /// **'Прочитано'**
  String get messageRead;

  /// Own message that failed to send; title of the retry menu
  ///
  /// In ru, this message translates to:
  /// **'Не отправлено'**
  String get messageFailed;

  /// Pill over the chat when new messages arrived below the visible part
  ///
  /// In ru, this message translates to:
  /// **'Новые сообщения'**
  String get newMessagesBelow;

  /// A message kind this app version can't show yet (photo, voice, report card)
  ///
  /// In ru, this message translates to:
  /// **'Неподдерживаемое сообщение'**
  String get unsupportedMessage;

  /// System message: someone joined the project team
  ///
  /// In ru, this message translates to:
  /// **'{name} теперь в чате'**
  String systemMemberAdded(String name);

  /// System message: someone left the project team or the company
  ///
  /// In ru, this message translates to:
  /// **'{name} больше не в чате'**
  String systemMemberRemoved(String name);

  /// Name of a person who is no longer in the company
  ///
  /// In ru, this message translates to:
  /// **'Бывший сотрудник'**
  String get formerMember;

  /// Instead of the message field in a direct chat with a removed member
  ///
  /// In ru, this message translates to:
  /// **'Сотрудник больше не работает в компании, написать ему нельзя'**
  String get peerLeftCompany;

  /// The user is no longer in the chat
  ///
  /// In ru, this message translates to:
  /// **'Чат недоступен'**
  String get chatUnavailable;

  /// Hint under chatUnavailable
  ///
  /// In ru, this message translates to:
  /// **'Вас исключили из объекта, или чат больше не доступен'**
  String get chatUnavailableHint;

  /// Project page tile that opens the project chat
  ///
  /// In ru, this message translates to:
  /// **'Чат объекта'**
  String get projectChat;

  /// Person sheet button that opens the direct chat
  ///
  /// In ru, this message translates to:
  /// **'Написать'**
  String get writeMessage;

  /// More photos were picked than allowed; the extra ones are dropped
  ///
  /// In ru, this message translates to:
  /// **'Можно добавить не больше {count} фото'**
  String photoLimitReached(int count);

  /// Semantics of the spinner on a photo being compressed
  ///
  /// In ru, this message translates to:
  /// **'Фото обрабатывается'**
  String get photoProcessing;

  /// Red mark on a photo that couldn't be compressed; title of its retry or remove sheet
  ///
  /// In ru, this message translates to:
  /// **'Фото не обработано'**
  String get photoProcessingFailed;

  /// Capture time of a report photo in the viewer: «Снято 11:42» or «Снято 25 октября, 18:10»
  ///
  /// In ru, this message translates to:
  /// **'Снято {time}'**
  String photoTakenAt(String time);

  /// Badge on a report photo taken on another day than the report was sent
  ///
  /// In ru, this message translates to:
  /// **'Снято не сегодня'**
  String get photoTakenNotToday;

  /// Close button of the full-screen photo viewer
  ///
  /// In ru, this message translates to:
  /// **'Закрыть просмотр'**
  String get photoViewerClose;

  /// Chat list preview of a message with one photo
  ///
  /// In ru, this message translates to:
  /// **'Фото'**
  String get photoMessage;

  /// The «+» button left of the chat message field
  ///
  /// In ru, this message translates to:
  /// **'Прикрепить фото'**
  String get attachPhoto;

  /// Camera button inside the chat message field
  ///
  /// In ru, this message translates to:
  /// **'Сфотографировать'**
  String get takePhotoNow;

  /// Hint of the chat message field while photos are attached: the text becomes their caption
  ///
  /// In ru, this message translates to:
  /// **'Подпись'**
  String get photoCaptionHint;

  /// Last cell of a photo grid in a chat message: how many more photos the message has
  ///
  /// In ru, this message translates to:
  /// **'+{count}'**
  String morePhotos(int count);

  /// Snack bar when sending while an attached photo failed to compress
  ///
  /// In ru, this message translates to:
  /// **'Одно из фото не обработано. Повторите его или уберите'**
  String get photoFailedBeforeSend;

  /// Semantics of the progress ring on a photo being sent
  ///
  /// In ru, this message translates to:
  /// **'Фото загружается'**
  String get photoUploading;

  /// Chat list preview of a voice message: «Голосовое · 0:42»
  ///
  /// In ru, this message translates to:
  /// **'Голосовое'**
  String get voiceMessage;

  /// Microphone button of the chat message field: hold to record
  ///
  /// In ru, this message translates to:
  /// **'Записать голосовое'**
  String get recordVoice;

  /// Snack bar after a tap or a recording shorter than a second
  ///
  /// In ru, this message translates to:
  /// **'Удерживайте, чтобы записать'**
  String get voiceHoldToRecord;

  /// The microphone permission was refused
  ///
  /// In ru, this message translates to:
  /// **'Нет доступа к микрофону. Его можно включить в настройках приложения'**
  String get microphoneAccessDenied;

  /// The microphone failed to start or stop
  ///
  /// In ru, this message translates to:
  /// **'Не удалось записать голосовое'**
  String get voiceRecordFailed;

  /// Semantics of the blinking dot while recording
  ///
  /// In ru, this message translates to:
  /// **'Идёт запись'**
  String get voiceRecording;

  /// Hint while holding the microphone
  ///
  /// In ru, this message translates to:
  /// **'Влево — отмена'**
  String get voiceSlideToCancel;

  /// Lock hint above the microphone while holding it
  ///
  /// In ru, this message translates to:
  /// **'Вверх — запись без удержания'**
  String get voiceSlideToLock;

  /// Stops a locked recording into a draft
  ///
  /// In ru, this message translates to:
  /// **'Остановить'**
  String get voiceStop;

  /// Plays the recorded draft before sending
  ///
  /// In ru, this message translates to:
  /// **'Прослушать'**
  String get voiceListen;

  /// Play button of a voice note
  ///
  /// In ru, this message translates to:
  /// **'Воспроизвести'**
  String get voicePlay;

  /// Pause button of a voice note
  ///
  /// In ru, this message translates to:
  /// **'Пауза'**
  String get voicePause;

  /// Playback speed button: 1×, 1.5×, 2×
  ///
  /// In ru, this message translates to:
  /// **'{speed}×'**
  String voiceSpeed(String speed);

  /// Semantics of the dot on someone else's voice note not played yet
  ///
  /// In ru, this message translates to:
  /// **'Не прослушано'**
  String get voiceUnheard;

  /// Semantics of the ring around a voice note being sent
  ///
  /// In ru, this message translates to:
  /// **'Голосовое загружается'**
  String get voiceUploading;

  /// Semantics of the ring around a voice note whose file downloads before it plays
  ///
  /// In ru, this message translates to:
  /// **'Голосовое скачивается'**
  String get voiceDownloading;
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
