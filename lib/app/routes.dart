/// Route path constants.
abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  // Owner routes
  static const ownerProjects = '/owner/projects';
  static const ownerProjectForm = '/owner/projects/new';
  static const ownerTeam = '/owner/team';
  static const ownerReports = '/owner/reports';
  static const ownerProfile = '/owner/profile';

  // Foreman routes
  static const foremanProjects = '/foreman/projects';
  static const foremanNewReport = '/foreman/new-report';
  static const foremanProfile = '/foreman/profile';

  // Shared detail routes
  static const reportDetail = '/reports/:id';
}
