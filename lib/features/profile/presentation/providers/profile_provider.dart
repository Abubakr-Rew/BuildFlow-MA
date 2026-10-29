import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light/dark theme chosen on the profile screen; the app root watches it.
/// The choice is saved locally and restored in main() before the first frame.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storageKey = 'theme_mode';

  // Startup waits for the restore, so never let storage hold it up for long.
  static const _restoreTimeout = Duration(seconds: 1);

  @override
  ThemeMode build() => ThemeMode.system;

  /// Loads the saved choice; keeps the system theme if there is none
  /// or storage fails.
  Future<void> restore() async {
    try {
      final saved = await ref
          .read(localStorageProvider)
          .readString(_storageKey)
          .timeout(_restoreTimeout);
      state = ThemeMode.values.asNameMap()[saved] ?? state;
    } catch (e) {
      debugPrint('Theme mode restore failed: $e');
    }
  }

  /// Applies [mode] right away and saves it for the next launch.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      await ref.read(localStorageProvider).saveString(_storageKey, mode.name);
    } catch (e) {
      debugPrint('Theme mode save failed: $e');
    }
  }
}
