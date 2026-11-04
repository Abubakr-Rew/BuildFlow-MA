import 'package:buildflow/app/l10n/failure_messages.dart';
import 'package:buildflow/app/l10n/generated/app_localizations_ru.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsRu();

  // Every code must be listed here: a new FailureCode fails the
  // completeness test until it gets its expected text.
  final expected = {
    FailureCode.network: l10n.errorNetwork,
    FailureCode.timeout: l10n.errorTimeout,
    FailureCode.server: l10n.errorServer,
    FailureCode.invalidCredentials: l10n.errorInvalidCredentials,
    FailureCode.emailTaken: l10n.errorEmailTaken,
    FailureCode.invalidInviteCode: l10n.errorInvalidInviteCode,
    FailureCode.sessionExpired: l10n.errorSessionExpired,
    FailureCode.accountDisabled: l10n.errorAccountDisabled,
    FailureCode.forbidden: l10n.errorForbidden,
    FailureCode.notFound: l10n.errorNotFound,
    FailureCode.validation: l10n.errorValidation,
    FailureCode.tooManyRequests: l10n.errorTooManyRequests,
    FailureCode.photoProcessing: l10n.errorPhotoProcessing,
    FailureCode.unknown: l10n.errorUnknown,
  };

  group('failureMessage', () {
    test('covers every FailureCode', () {
      expect(expected.keys.toSet(), FailureCode.values.toSet());
    });

    for (final MapEntry(key: code, value: text) in expected.entries) {
      test('${code.name} → «$text»', () {
        expect(l10n.failureMessage(Failure(code)), text);
      });
    }

    test('every code has its own text', () {
      final texts = FailureCode.values
          .map((code) => l10n.failureMessage(Failure(code)))
          .toSet();
      expect(texts, hasLength(FailureCode.values.length));
    });

    test('never shows the debug message', () {
      const failure = Failure(
        FailureCode.emailTaken,
        message: 'User with this email already exists (server text)',
        statusCode: 409,
      );
      expect(l10n.failureMessage(failure), l10n.errorEmailTaken);
    });

    test('shows the generic text for an unexpected exception', () {
      expect(l10n.failureMessage(Exception('boom')), l10n.errorUnknown);
      expect(l10n.failureMessage(StateError('bad')), l10n.errorUnknown);
    });

    test('keeps the key texts users already know', () {
      expect(
        l10n.failureMessage(const Failure(FailureCode.invalidCredentials)),
        'Неверный email или пароль',
      );
      expect(
        l10n.failureMessage(const Failure(FailureCode.emailTaken)),
        'Пользователь с таким email уже существует',
      );
      expect(
        l10n.failureMessage(const Failure(FailureCode.invalidInviteCode)),
        'Код приглашения неверный, уже использован или истёк',
      );
    });
  });
}
