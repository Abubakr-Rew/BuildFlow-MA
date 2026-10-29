import 'package:buildflow/app/l10n/generated/app_localizations.dart';
import 'package:buildflow/app/router.dart';
import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// In-memory storage so FakeAuthRepository runs without platform channels.
class MemorySecureStorage extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveToken(String token) async => _store['token'] = token;

  @override
  Future<String?> readToken() async => _store['token'];

  @override
  Future<void> saveUserId(String id) async => _store['userId'] = id;

  @override
  Future<String?> readUserId() async => _store['userId'];

  @override
  Future<void> clearAll() async => _store.clear();
}

/// The whole app with the real router and fake repositories, set up like
/// `pumpTestApp`: a wide surface and smaller text for the Ahem font.
class FullApp {
  FullApp._(this.tester, this.container, this.router);

  final WidgetTester tester;
  final ProviderContainer container;
  final GoRouter router;

  static Future<FullApp> pump(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        secureStorageProvider.overrideWithValue(MemorySecureStorage()),
        ...overrides,
      ],
    );
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(0.7)),
            child: child!,
          ),
        ),
      ),
    );
    final app = FullApp._(tester, container, router);
    await app.settle();
    return app;
  }

  String get location => router.routerDelegate.currentConfiguration.uri.path;

  /// Lets the fake repositories' latency (< 1 s each, often chained) pass.
  /// Not `pumpAndSettle`: progress indicators never settle.
  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> login(String email) async {
    final done = container
        .read(authProvider.notifier)
        .login(email: email, password: '123456');
    await settle();
    expect((await done).isSuccess, isTrue);
  }

  Future<void> logout() async {
    final done = container.read(authProvider.notifier).logout();
    await settle();
    await done;
  }

  /// Unmounts the app before the container (and the router) is disposed.
  /// Requests the last screens started may still be waiting out their
  /// random fake latency, and a timer left pending fails the test, so it
  /// runs out first: each request waits under a second.
  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    container.dispose();
  }
}
