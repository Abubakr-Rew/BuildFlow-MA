import 'dart:io';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/features/auth/data/supabase_auth_repository.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_supabase.dart';

const _userId = 'a0000000-0000-4000-8000-000000000001';

const _owner = User(
  id: _userId,
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

Map<String, dynamic> get _me => {
      'user': _owner.toJson()..['role'] = 'owner',
      'company': {'id': 'company-1', 'name': 'СтройБишкек'},
    };

void main() {
  late FakeSupabase supabase;
  late LocalStorageService storage;
  late SupabaseAuthRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    supabase = FakeSupabase()
      ..on('POST', '/auth/v1/logout', (_) => const FakeReply(204));
    storage = LocalStorageService();
    repo = SupabaseAuthRepository(
      gateway: supabase.gateway,
      localStorage: storage,
    );
  });
  tearDown(() => supabase.dispose());

  void signInAnswers(FakeReply reply) =>
      supabase.on('POST', '/auth/v1/token', (_) => reply);

  FakeReply session() => FakeReply(
        200,
        FakeSupabase.sessionJson(_userId, email: _owner.email),
      );

  group('login', () {
    test('signs in with GoTrue, then loads the profile', () async {
      signInAnswers(session());
      supabase.rpc('get_me', _me);

      final result = await repo.login(
        email: ' owner@buildflow.kg ',
        password: '123456',
      );

      expect(result.value, _owner);
      expect(repo.currentUser, _owner);
      final token = supabase.requestsTo('/auth/v1/token').single;
      expect(token.url.queryParameters['grant_type'], 'password');
      expect(token.json['email'], 'owner@buildflow.kg');
      expect(await storage.readJson(cachedProfileKey), isNotNull);
    });

    test('a wrong password', () async {
      signInAnswers(FakeReply.auth(400, 'invalid_credentials'));

      final result = await repo.login(email: 'a@b.kg', password: 'x');

      expect(result.failure.code, FailureCode.invalidCredentials);
      expect(supabase.rpcCalls('get_me'), isEmpty);
    });

    test('a banned (removed) member is told access is closed', () async {
      signInAnswers(FakeReply.auth(400, 'user_banned'));

      final result = await repo.login(email: 'a@b.kg', password: '123456');

      expect(result.failure.code, FailureCode.accountDisabled);
    });

    test('a removed profile ends the fresh session', () async {
      signInAnswers(session());
      supabase.rpcFails('get_me', 403, 'account_removed');

      final result = await repo.login(email: 'a@b.kg', password: '123456');

      expect(result.failure.code, FailureCode.accountDisabled);
      expect(supabase.client.auth.currentSession, isNull);
      expect(repo.currentUser, isNull);
    });

    test('no connection', () async {
      supabase.on(
        'POST',
        '/auth/v1/token',
        (_) => throw const SocketException('offline'),
      );

      final result = await repo.login(email: 'a@b.kg', password: '123456');

      expect(result.failure.code, FailureCode.network);
    });
  });

  group('register', () {
    test('sends the name and company for the registration trigger', () async {
      supabase
        ..on('POST', '/auth/v1/signup', (_) => session())
        ..rpc('get_me', _me);

      final result = await repo.register(
        email: 'owner@buildflow.kg',
        password: '123456',
        name: 'Асан Бекович',
        companyName: 'СтройБишкек',
      );

      expect(result.value, _owner);
      final signup = supabase.requestsTo('/auth/v1/signup').single.json;
      expect(signup['data'], {
        'name': 'Асан Бекович',
        'company_name': 'СтройБишкек',
      });
    });

    test('a taken email', () async {
      supabase.on(
        'POST',
        '/auth/v1/signup',
        (_) => FakeReply.auth(422, 'user_already_exists'),
      );

      final result = await repo.register(
        email: 'owner@buildflow.kg',
        password: '123456',
        name: 'Асан',
        companyName: 'Ко',
      );

      expect(result.failure.code, FailureCode.emailTaken);
    });
  });

  group('join', () {
    test('joins through the Edge Function and takes over its session',
        () async {
      const worker = User(
        id: 'w1',
        email: 'new@buildflow.kg',
        name: 'Новый',
        role: UserRole.worker,
        companyId: 'company-1',
      );
      supabase
        ..function(
          'join',
          FakeReply(201, {
            'session': {'access_token': 'a', 'refresh_token': 'r-join'},
            'user': worker.toJson(),
            'company': {'id': 'company-1', 'name': 'СтройБишкек'},
          }),
        )
        ..on(
          'POST',
          '/auth/v1/token',
          (_) => FakeReply(200, FakeSupabase.sessionJson('w1')),
        );

      final result = await repo.joinWithInviteCode(
        email: 'new@buildflow.kg',
        password: '123456',
        name: 'Новый',
        inviteCode: 'K7M2QX',
      );

      expect(result.value, worker);
      final request = supabase.requestsTo('/functions/v1/join').single;
      expect(request.json['inviteCode'], 'K7M2QX');
      expect(request.headers['X-Device-Id'], isNotEmpty);
      final refresh = supabase.requestsTo('/auth/v1/token').single;
      expect(refresh.url.queryParameters['grant_type'], 'refresh_token');
      expect(refresh.json['refresh_token'], 'r-join');
      expect(supabase.client.auth.currentUser?.id, 'w1');
    });

    test('the device id stays the same between attempts', () async {
      supabase.function(
        'join',
        const FakeReply(404, {'error': 'x', 'hint': 'invalid_invite_code'}),
      );
      for (var i = 0; i < 2; i++) {
        await repo.joinWithInviteCode(
          email: 'a@b.kg',
          password: '123456',
          name: 'А',
          inviteCode: 'AAAAAA',
        );
      }
      final ids = supabase
          .requestsTo('/functions/v1/join')
          .map((r) => r.headers['X-Device-Id'])
          .toSet();
      expect(ids, hasLength(1));
    });

    test('the function errors', () async {
      Future<FailureCode> codeOf(FakeReply reply) async {
        supabase.function('join', reply);
        final result = await repo.joinWithInviteCode(
          email: 'a@b.kg',
          password: '123456',
          name: 'А',
          inviteCode: 'AAAAAA',
        );
        return result.failure.code;
      }

      expect(
        await codeOf(const FakeReply(404, {'hint': 'invalid_invite_code'})),
        FailureCode.invalidInviteCode,
      );
      expect(
        await codeOf(const FakeReply(409, {'hint': 'email_taken'})),
        FailureCode.emailTaken,
      );
      expect(
        await codeOf(
          const FakeReply(429, {'hint': 'too_many_requests'}, {'Retry-After': '60'}),
        ),
        FailureCode.tooManyRequests,
      );
    });
  });

  group('restoreSession', () {
    test('without a stored session', () async {
      final result = await repo.restoreSession();
      expect(result.failure.code, FailureCode.sessionExpired);
    });

    test('loads the profile of the stored session', () async {
      await supabase.signIn(_userId);
      supabase.rpc('get_me', _me);

      expect((await repo.restoreSession()).value, _owner);
    });

    test('offline it opens with the last profile of the same user', () async {
      await supabase.signIn(_userId);
      await storage.saveJson(cachedProfileKey, _owner.toJson());
      supabase.on(
        'POST',
        '/rest/v1/rpc/get_me',
        (_) => throw const SocketException('offline'),
      );

      expect((await repo.restoreSession()).value, _owner);
      expect(supabase.client.auth.currentSession, isNotNull);
    });

    test("offline another user's cached profile isn't used", () async {
      await supabase.signIn('someone-else');
      await storage.saveJson(cachedProfileKey, _owner.toJson());
      supabase.on(
        'POST',
        '/rest/v1/rpc/get_me',
        (_) => throw const SocketException('offline'),
      );

      expect(
        (await repo.restoreSession()).failure.code,
        FailureCode.network,
      );
    });

    test('a removed account is closed and signed out', () async {
      await supabase.signIn(_userId);
      supabase.rpcFails('get_me', 403, 'account_removed');

      final result = await repo.restoreSession();

      expect(result.failure.code, FailureCode.accountDisabled);
      expect(supabase.client.auth.currentSession, isNull);
    });
  });

  test('logout ends the session and forgets the profile', () async {
    signInAnswers(session());
    supabase.rpc('get_me', _me);
    await repo.login(email: 'owner@buildflow.kg', password: '123456');

    await repo.logout();

    expect(supabase.client.auth.currentSession, isNull);
    expect(repo.currentUser, isNull);
    expect(await storage.readJson(cachedProfileKey), isNull);
  });

  test('a session ended by the server forgets the profile too', () async {
    signInAnswers(session());
    supabase
      ..rpc('get_me', _me)
      ..rpcFails('get_projects', 403, 'account_removed');
    await repo.login(email: 'owner@buildflow.kg', password: '123456');
    final ended = <Failure>[];
    repo.sessionEnded.listen(ended.add);

    await supabase.gateway.rpc('get_projects', (j) => j);
    await pumpEventQueue();

    expect(ended.single.code, FailureCode.sessionExpired);
    expect(repo.currentUser, isNull);
    expect(await storage.readJson(cachedProfileKey), isNull);
  });
}
