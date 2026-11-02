import 'package:buildflow/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BackendConfig parse({
    String backend = '',
    String url = '',
    String key = '',
    bool release = false,
  }) =>
      BackendConfig.parse(
        backend: backend,
        supabaseUrl: url,
        supabaseAnonKey: key,
        release: release,
      );

  group('BackendConfig.parse', () {
    test('unset BACKEND is fake in debug, profile and tests', () {
      expect(parse().backend, Backend.fake);
    });

    test('a release build without BACKEND fails instead of using fake', () {
      expect(
        () => parse(release: true),
        throwsA(isA<BackendConfigError>()),
      );
    });

    test('a release build may be an explicit demo', () {
      expect(parse(backend: 'fake', release: true).backend, Backend.fake);
    });

    test('supabase takes the URL and the key', () {
      final config = parse(
        backend: 'supabase',
        url: ' http://127.0.0.1:54321 ',
        key: 'anon',
        release: true,
      );
      expect(config.backend, Backend.supabase);
      expect(config.supabaseUrl, 'http://127.0.0.1:54321');
      expect(config.supabaseAnonKey, 'anon');
    });

    test('supabase without a URL or a key fails in any build', () {
      for (final release in [false, true]) {
        expect(
          () => parse(backend: 'supabase', key: 'anon', release: release),
          throwsA(isA<BackendConfigError>()),
        );
        expect(
          () => parse(
            backend: 'supabase',
            url: 'http://127.0.0.1:54321',
            release: release,
          ),
          throwsA(isA<BackendConfigError>()),
        );
      }
    });

    test('an unknown backend or a malformed URL fails', () {
      expect(() => parse(backend: 'api'), throwsA(isA<BackendConfigError>()));
      expect(
        () => parse(backend: 'supabase', url: '127.0.0.1', key: 'anon'),
        throwsA(isA<BackendConfigError>()),
      );
    });
  });
}
