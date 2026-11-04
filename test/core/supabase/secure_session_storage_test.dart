import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/core/supabase/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the session survives a restart through the secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final first = SecureSessionStorage(SecureStorageService());
    await first.initialize();
    expect(await first.hasAccessToken(), isFalse);
    await first.persistSession('{"access_token":"t"}');

    // A new start reads what the last run saved.
    final second = SecureSessionStorage(SecureStorageService());
    await second.initialize();
    expect(await second.hasAccessToken(), isTrue);
    expect(await second.accessToken(), '{"access_token":"t"}');

    await second.removePersistedSession();
    final third = SecureSessionStorage(SecureStorageService());
    await third.initialize();
    expect(await third.accessToken(), isNull);
  });
}
