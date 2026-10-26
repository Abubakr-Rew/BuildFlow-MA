import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Storage whose every call fails, like a corrupted preferences file.
class _BrokenStorage extends LocalStorageService {
  @override
  Future<String?> readString(String key) async => throw Exception('broken');

  @override
  Future<bool> saveString(String key, String value) async =>
      throw Exception('broken');
}

void main() {
  // A fresh container over the same preferences is an app restart.
  ProviderContainer launch({List<Override> overrides = const []}) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  Future<ThemeMode> restored(ProviderContainer container) async {
    await container.read(themeModeProvider.notifier).restore();
    return container.read(themeModeProvider);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ThemeModeNotifier', () {
    test('follows the system theme when nothing is saved', () async {
      expect(await restored(launch()), ThemeMode.system);
    });

    test('setMode applies the theme immediately', () async {
      final container = launch();
      final saving =
          container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      await saving;
    });

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      test('keeps ${mode.name} after a restart', () async {
        await launch().read(themeModeProvider.notifier).setMode(mode);
        expect(await restored(launch()), mode);
      });
    }

    test('ignores an unknown saved value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      expect(await restored(launch()), ThemeMode.system);
    });

    test('survives broken storage', () async {
      final container = launch(
        overrides: [localStorageProvider.overrideWithValue(_BrokenStorage())],
      );
      expect(await restored(container), ThemeMode.system);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });
}
