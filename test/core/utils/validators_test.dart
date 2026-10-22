import 'package:buildflow/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.email', () {
    test('returns required message for null', () {
      expect(
        Validators.email(
          null,
          requiredMsg: 'required',
          invalidMsg: 'invalid',
        ),
        'required',
      );
    });

    test('returns required message for empty string', () {
      expect(
        Validators.email(
          '',
          requiredMsg: 'required',
          invalidMsg: 'invalid',
        ),
        'required',
      );
    });

    test('returns invalid message for bad email', () {
      expect(
        Validators.email(
          'not-an-email',
          requiredMsg: 'required',
          invalidMsg: 'invalid',
        ),
        'invalid',
      );
    });

    test('returns null for valid email', () {
      expect(
        Validators.email(
          'test@example.com',
          requiredMsg: 'required',
          invalidMsg: 'invalid',
        ),
        isNull,
      );
    });
  });

  group('Validators.password', () {
    test('returns required message for null', () {
      expect(
        Validators.password(
          null,
          requiredMsg: 'required',
          shortMsg: 'short',
        ),
        'required',
      );
    });

    test('returns short message for < 6 chars', () {
      expect(
        Validators.password(
          '123',
          requiredMsg: 'required',
          shortMsg: 'short',
        ),
        'short',
      );
    });

    test('returns null for valid password', () {
      expect(
        Validators.password(
          '123456',
          requiredMsg: 'required',
          shortMsg: 'short',
        ),
        isNull,
      );
    });
  });

  group('Validators.required', () {
    test('returns message for null', () {
      expect(Validators.required(null, message: 'fill it'), 'fill it');
    });

    test('returns message for empty', () {
      expect(Validators.required('', message: 'fill it'), 'fill it');
    });

    test('returns message for whitespace only', () {
      expect(Validators.required('   ', message: 'fill it'), 'fill it');
    });

    test('returns null for valid input', () {
      expect(Validators.required('hello', message: 'fill it'), isNull);
    });
  });
}
