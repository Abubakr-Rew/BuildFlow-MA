import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/supabase/supabase_failures.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:uuid/uuid.dart';

/// Local storage key of the last profile from `get_me`: a restart without
/// a connection opens the app instead of the login screen.
const cachedProfileKey = 'cached_profile';

/// Local storage key of this install's id, sent as `X-Device-Id` to `join`:
/// the server limits invite code attempts per device.
const deviceIdKey = 'device_id';

/// [AuthRepository] over Supabase Auth: sign-in and registration through
/// GoTrue, joining through the Edge Function `join`, the profile from
/// `get_me` (docs/supabase-plan.md, «Авторизация»). supabase_flutter keeps
/// and refreshes the session; [sessionEnded] reports when it ends on its
/// own.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({required this.gateway, required this.localStorage}) {
    // Whatever ended the session, its profile isn't this device's to keep.
    gateway.sessionEnded.listen((_) => _forget());
  }

  final SupabaseGateway gateway;

  /// The cached profile and the device id.
  final LocalStorageService localStorage;
  User? _user;

  GoTrueClient get _auth => gateway.client.auth;

  @override
  User? get currentUser => _user;

  @override
  Stream<Failure> get sessionEnded => gateway.sessionEnded;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) =>
      _signIn(
        () => _auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) =>
      // The registration trigger reads name and company_name and creates
      // the company with its director.
      _signIn(
        () => _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'name': name.trim(), 'company_name': companyName.trim()},
        ),
      );

  @override
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async {
    final joined = await gateway.invoke(
      'join',
      (json) => json! as Map<String, dynamic>,
      body: {
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'inviteCode': inviteCode,
      },
      headers: {'X-Device-Id': await _deviceId()},
      call: SupabaseCall.join,
    );
    if (joined case Err(:final failure)) return Err(failure);
    final body = joined.value;

    // The function signed the new member in; take over its session.
    final refreshToken =
        (body['session'] as Map<String, dynamic>?)?['refresh_token'];
    final session = await gateway.run(
      () => _auth.setSession(refreshToken as String),
      call: SupabaseCall.signIn,
    );
    if (session case Err(:final failure)) return Err(failure);

    final user = User.fromJson(body['user'] as Map<String, dynamic>);
    await _remember(user);
    return Success(user);
  }

  @override
  Future<Result<User>> restoreSession() async {
    final session = _auth.currentSession;
    if (session == null) {
      return const Err(
        Failure(FailureCode.sessionExpired, message: 'No stored session'),
      );
    }
    final me = await _me();
    if (me case Err(:final failure)) {
      // Offline at the site: the last profile of this session's user.
      final offline = failure.code == FailureCode.network ||
          failure.code == FailureCode.timeout ||
          failure.code == FailureCode.server;
      final cached = offline ? await _cachedProfile() : null;
      if (cached != null && cached.id == session.user.id) {
        _user = cached;
        return Success(cached);
      }
      if (!offline) await _endSession();
    }
    return me;
  }

  @override
  Future<Result<void>> logout() async {
    await gateway.signOut();
    await _forget();
    return const Success(null);
  }

  /// Runs a GoTrue sign-in or sign-up, then loads the profile. A profile
  /// that can't be loaded ends the fresh session.
  Future<Result<User>> _signIn(Future<AuthResponse> Function() request) async {
    final signedIn = await gateway.run(request, call: SupabaseCall.signIn);
    if (signedIn case Err(:final failure)) return Err(failure);
    if (signedIn.value.session == null) {
      // Only with email confirmation on, which this project has off.
      return const Err(
        Failure(FailureCode.unknown, message: 'Sign-up returned no session'),
      );
    }
    final me = await _me();
    if (me.isFailure) await _endSession();
    return me;
  }

  /// `get_me` → the profile, remembered for offline restarts.
  Future<Result<User>> _me() async {
    final me = await gateway.rpc(
      'get_me',
      (json) => User.fromJson(
        (json! as Map<String, dynamic>)['user'] as Map<String, dynamic>,
      ),
      call: SupabaseCall.signIn,
    );
    if (me case Success(:final value)) await _remember(value);
    return me;
  }

  Future<void> _remember(User user) async {
    _user = user;
    try {
      await localStorage.saveJson(cachedProfileKey, user.toJson());
    } on Exception catch (_) {
      // Only a convenience for offline restarts.
    }
  }

  Future<User?> _cachedProfile() async {
    try {
      final json = await localStorage.readJson(cachedProfileKey);
      return json == null ? null : User.fromJson(json);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _endSession() async {
    await gateway.signOut();
    await _forget();
  }

  Future<void> _forget() async {
    _user = null;
    try {
      await localStorage.remove(cachedProfileKey);
    } on Exception catch (_) {}
  }

  Future<String> _deviceId() async {
    try {
      final saved = await localStorage.readString(deviceIdKey);
      if (saved != null) return saved;
      final id = const Uuid().v4();
      await localStorage.saveString(deviceIdKey, id);
      return id;
    } on Exception catch (_) {
      return const Uuid().v4();
    }
  }
}
