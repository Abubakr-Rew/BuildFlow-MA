import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/team/data/api_team_repository.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => kUseMockData ? FakeTeamRepository() : ApiTeamRepository(),
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
      failure: (f) => throw f,
    );
  }

  /// Removes the member from the company, then from every project.
  ///
  /// The result is the removal itself: the project cleanup is best effort,
  /// since project pages only list current members anyway.
  Future<Result<void>> removeMember(Member member) async {
    final repo = ref.read(teamRepositoryProvider);
    final result = await repo.removeMember(member.id);
    if (result.isFailure) return result;

    try {
      final projectsNotifier = ref.read(projectsProvider.notifier);
      final projects = await ref.read(projectsProvider.future);
      for (final project in projects) {
        if (project.foremanIds.contains(member.userId) ||
            project.workerIds.contains(member.userId)) {
          await projectsNotifier.setTeam(
            project,
            foremanIds:
                project.foremanIds.where((id) => id != member.userId).toList(),
            workerIds:
                project.workerIds.where((id) => id != member.userId).toList(),
          );
        }
      }
    } on Failure catch (f) {
      debugPrint('Project cleanup after removing ${member.id} failed: $f');
    }

    ref.invalidateSelf();
    return result;
  }
}
