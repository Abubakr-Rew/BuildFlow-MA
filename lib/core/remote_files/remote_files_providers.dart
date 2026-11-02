import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Storage files on the phone; tests override it.
final remoteFilesProvider = Provider<RemoteFiles>(
  (ref) => RemoteFiles(
    gateway: switch (kBackend) {
      Backend.fake => null,
      Backend.supabase => ref.watch(supabaseGatewayProvider),
    },
  ),
);
