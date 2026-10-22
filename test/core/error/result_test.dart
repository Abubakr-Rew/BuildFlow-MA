import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success isSuccess returns true', () {
      const result = Success<int>(42);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
    });

    test('Err isFailure returns true', () {
      const result = Err<int>(NetworkFailure(message: 'offline'));
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('Success.value returns the data', () {
      const result = Success<String>('hello');
      expect(result.value, 'hello');
    });

    test('Err.value throws StateError', () {
      const result = Err<String>(AuthFailure(message: 'denied'));
      expect(() => result.value, throwsStateError);
    });

    test('Success.failure throws StateError', () {
      const result = Success<int>(1);
      expect(() => result.failure, throwsStateError);
    });

    test('Err.failure returns the failure', () {
      const result = Err<int>(StorageFailure(message: 'disk full'));
      expect(result.failure, isA<StorageFailure>());
      expect(result.failure.message, 'disk full');
    });

    test('map transforms Success value', () {
      const result = Success<int>(5);
      final mapped = result.map((v) => v * 2);
      expect(mapped.isSuccess, isTrue);
      expect(mapped.value, 10);
    });

    test('map passes through Err unchanged', () {
      const Result<int> result = Err(NetworkFailure(message: 'fail'));
      final mapped = result.map((v) => v * 2);
      expect(mapped.isFailure, isTrue);
      expect(mapped.failure.message, 'fail');
    });

    test('when calls success handler for Success', () {
      const result = Success<int>(42);
      final output = result.when(
        success: (data) => 'got $data',
        failure: (f) => 'failed: ${f.message}',
      );
      expect(output, 'got 42');
    });

    test('when calls failure handler for Err', () {
      const Result<int> result = Err(AuthFailure(message: 'nope'));
      final output = result.when(
        success: (data) => 'got $data',
        failure: (f) => 'failed: ${f.message}',
      );
      expect(output, 'failed: nope');
    });
  });

  group('Failure', () {
    test('NetworkFailure has correct message', () {
      const f = NetworkFailure(message: 'timeout');
      expect(f.message, 'timeout');
    });

    test('AuthFailure has correct message', () {
      const f = AuthFailure(message: 'invalid credentials');
      expect(f.message, 'invalid credentials');
    });

    test('ServerFailure has correct message', () {
      const f = ServerFailure(message: '500');
      expect(f.message, '500');
    });

    test('StorageFailure has correct message', () {
      const f = StorageFailure(message: 'not found');
      expect(f.message, 'not found');
    });

    test('ValidationFailure has correct message', () {
      const f = ValidationFailure(message: 'required');
      expect(f.message, 'required');
    });
  });
}
