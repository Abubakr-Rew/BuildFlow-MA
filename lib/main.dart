import 'dart:async';

import 'package:buildflow/app/app.dart';
import 'package:buildflow/app/config_error_app.dart';
import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/photos/photo_providers.dart';
import 'package:buildflow/core/storage/storage_providers.dart';
import 'package:buildflow/core/supabase/secure_session_storage.dart';
import 'package:buildflow/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A build without a usable backend stops here, on a screen that says
  // why, rather than starting on demo data or failing on the first request.
  final BackendConfig config;
  try {
    config = kBackendConfig;
  } on BackendConfigError catch (e) {
    debugPrint('$e');
    runApp(ConfigErrorApp(details: e.message));
    return;
  }
  debugPrint('Backend: ${config.backend.name}');

  // The bundled Inter font is under the OFL, which travels with the font.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/inter/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter'], license);
  });

  // Lock orientation to portrait for construction site usage
  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  // Restore the saved theme before the first frame, so a dark-theme user
  // doesn't see the light theme flash on every launch.
  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).restore();

  // The stored session is read here (secure storage, with timeouts) and
  // refreshed in the background; AuthNotifier restores the user on the
  // splash screen.
  if (config.backend == Backend.supabase) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(container.read(secureStorageProvider)),
        // Password sign-in only: no magic links or OAuth codes to catch,
        // so no PKCE either.
        detectSessionInUri: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BuildFlowApp(),
    ),
  );

  // Off the startup path: a camera shot lost when Android killed the app
  // under the camera goes back where it was taken; photo copies and picker
  // leftovers of earlier runs are swept (the send queues live in memory).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(container.read(lostCaptureProvider.notifier).recover());
    unawaited(container.read(photoCompressorProvider).sweep());
  });
}
