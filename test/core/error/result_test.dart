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
      const result = Err<int>(Failure(FailureCode.network, message: 'offline'));
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
    });

    test('Success.value returns the data', () {
      const result = Success<String>('hello');
      expect(result.value, 'hello');
    });

    test('Err.value throws StateError', () {
      const result = Err<String>(Failure(FailureCode.forbidden, message: 'denied'));
      expect(() => result.value, throwsStateError);
    });

    test('Success.failure throws StateError', () {
      const result = Success<int>(1);
      expect(() => result.failure, throwsStateError);
    });

    test('Err.failure returns the failure', () {
      const result = Err<int>(Failure(FailureCode.notFound, message: 'gone'));
      expect(result.failure.code, FailureCode.notFound);
      expect(result.failure.message, 'gone');
    });

    test('map transforms Success value', () {
      const result = Success<int>(5);
      final mapped = result.map((v) => v * 2);
      expect(mapped.isSuccess, isTrue);
      expect(mapped.value, 10);
    });

    test('map passes through Err unchanged', () {
      const Result<int> result = Err(Failure(FailureCode.network, message: 'fail'));
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
      const Result<int> result = Err(Failure(FailureCode.unknown, message: 'nope'));
      final output = result.when(
        success: (data) => 'got $data',
        failure: (f) => 'failed: ${f.message}',
      );
      expect(output, 'failed: nope');
    });
  });

  group('Failure', () {
    test('carries the code, debug message and status', () {
      const f = Failure(FailureCode.server, message: 'boom', statusCode: 503);
      expect(f.code, FailureCode.server);
      expect(f.message, 'boom');
      expect(f.statusCode, 503);
    });

    test('message is optional', () {
      const f = Failure(FailureCode.timeout);
      expect(f.message, isNull);
      expect(f.toString(), 'Failure(timeout)');
    });

    test('toString names the code and message for logs', () {
      const f = Failure(FailureCode.notFound, message: 'Project p-1 not found');
      expect(f.toString(), 'Failure(notFound: Project p-1 not found)');
    });

    test('can be thrown into AsyncValue.error as an Exception', () {
      expect(
        () => throw const Failure(FailureCode.unknown),
        throwsA(isA<Exception>()),
      );
    });
  });
}
