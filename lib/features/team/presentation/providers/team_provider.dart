import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => FakeTeamRepository(),
);

final membersProvider =
    AsyncNotifierProvider<MembersNotifier, List<Member>>(
  MembersNotifier.new,
);

class MembersNotifier extends AsyncNotifier<List<Member>> {
  @override
  Future<List<Member>> build() async {
    // Reload when the logged-in user changes.
    ref.watch(currentUserProvider);

    final repo = ref.watch(teamRepositoryProvider);
    final result = await repo.getMembers();
    return result.when(
      success: (members) => members,
      failure: (f) => throw Exception(f.message),
    );
  }
}

/// Holds the latest generated invite code.
final inviteCodeProvider =
    StateProvider<InviteCode?>((ref) => null);
