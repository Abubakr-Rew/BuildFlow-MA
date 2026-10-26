import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Light/dark theme chosen on the profile screen; the app root watches it.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
