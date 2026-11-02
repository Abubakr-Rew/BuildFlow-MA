import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around flutter_secure_storage for token persistence.
/// Never logs token values.
///
/// Every operation is guarded by a timeout: on some devices (notably
/// Xiaomi/MIUI) the Android KeyStore can hang indefinitely, which would
/// otherwise freeze login or splash forever. Writes are best-effort;
/// reads fall back to `null`.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _timeout = Duration(seconds: 3);

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _supabaseSessionKey = 'supabase_session';

  Future<void> saveToken(String token) => _write(_tokenKey, token);

  Future<String?> readToken() => _read(_tokenKey);

  Future<void> deleteToken() => _guard(() => _storage.delete(key: _tokenKey));

  Future<void> saveRefreshToken(String token) =>
      _write(_refreshTokenKey, token);

  Future<String?> readRefreshToken() => _read(_refreshTokenKey);

  Future<void> saveUserId(String userId) => _write(_userIdKey, userId);

  Future<String?> readUserId() => _read(_userIdKey);

  /// The Supabase session (access and refresh token, user) as JSON; kept
  /// and refreshed by supabase_flutter through `SecureSessionStorage`.
  Future<void> saveSupabaseSession(String json) =>
      _write(_supabaseSessionKey, json);

  Future<String?> readSupabaseSession() => _read(_supabaseSessionKey);

  Future<void> deleteSupabaseSession() =>
      _guard(() => _storage.delete(key: _supabaseSessionKey));

  Future<void> clearAll() => _guard(_storage.deleteAll);

  Future<void> _write(String key, String value) =>
      _guard(() => _storage.write(key: key, value: value));

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key).timeout(_timeout);
    } catch (e) {
      debugPrint('SecureStorage read "$key" failed: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _guard(Future<void> Function() op) async {
    try {
      await op().timeout(_timeout);
    } catch (e) {
      debugPrint('SecureStorage operation failed: ${e.runtimeType}');
    }
  }
}
