import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple JSON-based local storage for drafts and queued reports.
/// Uses SharedPreferences under the hood.
class LocalStorageService {
  // ignore: prefer_initializing_formals
  LocalStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Store a JSON-serializable object under [key].
  Future<bool> saveJson(String key, Map<String, dynamic> json) async {
    final prefs = await _preferences;
    return prefs.setString(key, jsonEncode(json));
  }

  /// Read a JSON object stored under [key].
  Future<Map<String, dynamic>?> readJson(String key) async {
    final prefs = await _preferences;
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Store a JSON list under [key].
  Future<bool> saveJsonList(
    String key,
    List<Map<String, dynamic>> list,
  ) async {
    final prefs = await _preferences;
    return prefs.setString(key, jsonEncode(list));
  }

  /// Read a JSON list stored under [key].
  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final prefs = await _preferences;
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Remove a key.
  Future<bool> remove(String key) async {
    final prefs = await _preferences;
    return prefs.remove(key);
  }

  /// Store a string value.
  Future<bool> saveString(String key, String value) async {
    final prefs = await _preferences;
    return prefs.setString(key, value);
  }

  /// Read a string value.
  Future<String?> readString(String key) async {
    final prefs = await _preferences;
    return prefs.getString(key);
  }

  /// Store a boolean value.
  Future<bool> saveBool(String key, {required bool value}) async {
    final prefs = await _preferences;
    return prefs.setBool(key, value);
  }

  /// Read a boolean value.
  Future<bool?> readBool(String key) async {
    final prefs = await _preferences;
    return prefs.getBool(key);
  }
}
