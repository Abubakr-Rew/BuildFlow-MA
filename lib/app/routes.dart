import 'package:buildflow/features/auth/domain/entities/user_role.dart';

/// Route path constants.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const join = '/join';

  // Owner (director) routes
  static const ownerProjects = '/owner/projects';
  static const ownerTeam = '/owner/team';
  static const ownerChats = '/owner/chats';
  static const ownerReports = '/owner/reports';
  static const ownerProfile = '/owner/profile';

  // Foreman routes
  static const foremanProjects = '/foreman/projects';
  static const foremanChats = '/foreman/chats';
  static const foremanNewReport = '/foreman/new-report';

  /// The foreman's report list, the «История» tab.
  static const foremanReports = '/foreman/reports';
  static const foremanProfile = '/foreman/profile';

  // Worker routes
  static const workerProjects = '/worker/projects';
  static const workerChats = '/worker/chats';
  static const workerReports = '/worker/reports';
  static const workerProfile = '/worker/profile';

  // Shared detail routes (full screen, above the bottom navigation)
  static const projectDetail = '/projects/:id';
  static const reportDetail = '/reports/:id';
  static const chatDetail = '/chats/:id';
  static const peopleSearch = '/people';

  static String project(String id) => '/projects/$id';
  static String report(String id) => '/reports/$id';
  static String chat(String id) => '/chats/$id';

  /// Start page for a role after login.
  static String homeFor(UserRole role) => switch (role) {
        UserRole.owner => ownerProjects,
        UserRole.foreman => foremanProjects,
        UserRole.worker => workerProjects,
      };

  /// The role's chats tab.
  static String chatsFor(UserRole role) => switch (role) {
        UserRole.owner => ownerChats,
        UserRole.foreman => foremanChats,
        UserRole.worker => workerChats,
      };

  /// Path prefix of the role's own section.
  static String prefixFor(UserRole role) => switch (role) {
        UserRole.owner => '/owner',
        UserRole.foreman => '/foreman',
        UserRole.worker => '/worker',
      };
}
