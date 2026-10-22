/// Status of a construction project.
enum ProjectStatus {
  active,
  paused,
  finished;

  bool get isActive => this == active;
}
