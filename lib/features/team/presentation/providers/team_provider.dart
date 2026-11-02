import 'package:buildflow/core/config.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/supabase/supabase_providers.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/presentation/providers/project_provider.dart';
import 'package:buildflow/features/team/data/fake_team_repository.dart';
import 'package:buildflow/features/team/data/supabase_team_repository.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/repositories/team_repository.dart';
import 'package:buildflow/features/team/presentation/providers/fake_team_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => switch (kBackend) {
    Backend.fake =>
      FakeTeamRepository(store: ref.watch(fakeTeamStoreProvider)),
    Backend.supabase => SupabaseTeamRepository(
        gateway: ref.watch(supabaseGatewayProvider),
      ),
  },
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

  /// Removes the member from the company. The server (in the fake, the
  /// project repository) also takes them off every project and chat, so
  /// the projects reload too (docs/api-contract.md,
  /// `DELETE /team/members/:id`).
  Future<Result<void>> removeMember(Member member) async {
    final repo = ref.read(teamRepositoryProvider);
    final result = await repo.removeMember(member.id);
    if (result.isFailure) return result;
    ref
      ..invalidate(projectsProvider)
      ..invalidateSelf();
    return result;
  }
}

/// Projects the user with the given id works on that the current user can
/// see: all of them for a director, the shared ones for a foreman or worker.
/// Empty while the projects load.
final memberProjectsProvider = Provider.family<List<Project>, String>(
  (ref, userId) {
    final projects = ref.watch(projectsProvider).valueOrNull ?? const [];
    return projects
        .where(
          (p) => p.foremanIds.contains(userId) || p.workerIds.contains(userId),
        )
        .toList();
  },
);

/// Ids of members opened from people search, newest first. Kept in memory
/// for the session and cleared when the user changes.
final recentPeopleProvider =
    NotifierProvider<RecentPeopleNotifier, List<String>>(
  RecentPeopleNotifier.new,
);

class RecentPeopleNotifier extends Notifier<List<String>> {
  static const limit = 5;

  @override
  List<String> build() {
    ref.watch(currentUserProvider);
    return const [];
  }

  /// Moves [memberId] to the top, keeping at most [limit] people.
  void add(String memberId) {
    state = [
      memberId,
      ...state.where((id) => id != memberId),
    ].take(limit).toList();
  }
}
