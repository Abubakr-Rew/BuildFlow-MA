import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where supabase_flutter keeps the session: the encrypted secure storage
/// instead of its default SharedPreferences, through [SecureStorageService]
/// and its timeouts (the MIUI KeyStore can hang; then there's no session
/// and the user signs in again).
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._storage);

  final SecureStorageService _storage;

  /// Read once in [initialize]: supabase_flutter asks [hasAccessToken] and
  /// then [accessToken], and each read may wait for the KeyStore.
  String? _session;

  @override
  Future<void> initialize() async {
    _session = await _storage.readSupabaseSession();
  }

  @override
  Future<bool> hasAccessToken() async => _session != null;

  @override
  Future<String?> accessToken() async => _session;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _session = persistSessionString;
    await _storage.saveSupabaseSession(persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    _session = null;
    await _storage.deleteSupabaseSession();
  }
}
