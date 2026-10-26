import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/core/error/failures.dart';

/// The one place where errors become user-facing text. Screens show errors
/// only through [failureMessage], never via `failure.message` or
/// `error.toString()`.
extension FailureMessages on AppLocalizations {
  /// Text for [error]: a [Failure] by its code, anything else (an
  /// unexpected exception) as a generic error.
  String failureMessage(Object error) => switch (error) {
        Failure(:final code) => _byCode(code),
        _ => errorUnknown,
      };

  String _byCode(FailureCode code) => switch (code) {
        FailureCode.network => errorNetwork,
        FailureCode.timeout => errorTimeout,
        FailureCode.server => errorServer,
        FailureCode.invalidCredentials => errorInvalidCredentials,
        FailureCode.emailTaken => errorEmailTaken,
        FailureCode.invalidInviteCode => errorInvalidInviteCode,
        FailureCode.sessionExpired => errorSessionExpired,
        FailureCode.forbidden => errorForbidden,
        FailureCode.notFound => errorNotFound,
        FailureCode.validation => errorValidation,
        FailureCode.unknown => errorUnknown,
      };
}
