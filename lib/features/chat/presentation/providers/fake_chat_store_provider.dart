import 'package:buildflow/core/config.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/projects/data/fake_project_repository.dart';
import 'package:buildflow/features/team/presentation/providers/fake_team_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The demo chat «server», shared by every user of the process. Lives in
/// its own file: project_provider reads it to keep project chats in sync,
/// and chat_provider imports team_provider, which imports project_provider.
final fakeChatStoreProvider = Provider<FakeChatStore>((ref) {
  final store = FakeChatStore(
    teamStore: ref.watch(fakeTeamStoreProvider),
    projects: FakeProjectRepository.seed,
    echo: kFakeChatEcho,
  );
  ref.onDispose(store.dispose);
  return store;
});
