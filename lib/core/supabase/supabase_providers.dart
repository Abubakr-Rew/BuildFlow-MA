import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The backend of `Backend.supabase` builds. `main` initializes Supabase
/// first; tests override this with a gateway over a mocked HTTP client.
final supabaseGatewayProvider = Provider<SupabaseGateway>((ref) {
  final gateway = SupabaseGateway(
    Supabase.instance.client,
    url: kBackendConfig.supabaseUrl,
    anonKey: kBackendConfig.supabaseAnonKey,
  );
  ref.onDispose(gateway.dispose);
  return gateway;
});
