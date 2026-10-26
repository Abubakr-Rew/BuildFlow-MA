/// Roles available in BuildFlow.
///
/// * [owner] — директор: управляет объектами, командой, видит все отчёты.
/// * [foreman] — прораб: отправляет отчёты по своим объектам.
/// * [worker] — строитель: видит свои объекты и отчёты по ним.
enum UserRole {
  owner,
  foreman,
  worker;

  bool get isOwner => this == owner;
  bool get isForeman => this == foreman;
  bool get isWorker => this == worker;
}
