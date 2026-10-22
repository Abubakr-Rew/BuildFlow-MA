/// Roles available in BuildFlow.
enum UserRole {
  owner,
  foreman;

  bool get isOwner => this == owner;
  bool get isForeman => this == foreman;
}
