import 'dart:async';

import 'package:buildflow/app/app.dart';
import 'package:buildflow/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const BuildFlowApp(),
    ),
  );
}
