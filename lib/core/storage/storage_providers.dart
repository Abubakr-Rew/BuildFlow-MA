import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/storage/secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Storage services ─────────────────────────────────────────
// The only place the storage services are created; tests override these.

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final localStorageProvider = Provider<LocalStorageService>(
  (ref) => LocalStorageService(),
);
