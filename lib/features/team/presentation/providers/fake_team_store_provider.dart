import 'package:buildflow/features/team/data/fake_team_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The demo company's members and invite codes, shared by the fake team and
/// auth repositories. Lives in its own file: auth_provider reads it, and
/// team_provider already imports auth_provider.
final fakeTeamStoreProvider = Provider<FakeTeamStore>((ref) => FakeTeamStore());
