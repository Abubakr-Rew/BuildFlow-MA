import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/error/result.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/remote_files_providers.dart';
import 'package:buildflow/core/supabase/supabase_providers.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/chat/presentation/providers/chat_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_chat_events.dart';
import '../../../../helpers/fake_supabase.dart';

User _user(String id) => User(
      id: id,
      email: '$id@buildflow.kg',
      name: id,
      role: UserRole.worker,
      companyId: 'c1',
    );

/// Signs in whoever [next] says.
class _Auth implements AuthRepository {
  User next = _user('u1');

  @override
  User? get currentUser => null;

  @override
  Stream<Failure> get sessionEnded => const Stream.empty();

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async =>
      Success(next);

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
    required String companyName,
  }) async =>
      Success(next);

  @override
  Future<Result<User>> joinWithInviteCode({
    required String email,
    required String password,
    required String name,
    required String inviteCode,
  }) async =>
      Success(next);

  @override
  Future<Result<User>> restoreSession() async => Success(next);

  @override
  Future<Result<void>> logout() async => const Success(null);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSupabase supabase;
  late _Auth auth;
  late Map<String, List<FakeChatEvents>> channels;
  late ProviderContainer container;
  late Directory cache;

  setUp(() async {
    supabase = FakeSupabase()..rpc('get_chats', <Object>[]);
    await supabase.signIn('u1');
    auth = _Auth();
    channels = {};
    cache = await Directory.systemTemp.createTemp('chat_provider_test');
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        supabaseGatewayProvider.overrideWithValue(supabase.gateway),
        remoteFilesProvider.overrideWithValue(
          RemoteFiles(cacheDir: () async => cache.path),
        ),
        chatRepositoryProvider.overrideWith(supabaseChatRepository),
        chatEventsFactoryProvider.overrideWithValue(
          (userId) => FakeChatEvents()
            ..let((events) => (channels[userId] ??= []).add(events)),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await pumpEventQueue();
    await supabase.dispose();
    await cache.delete(recursive: true);
  });

  Future<void> signIn(String userId) async {
    auth.next = _user(userId);
    await container
        .read(authProvider.notifier)
        .login(email: '$userId@buildflow.kg', password: '123456');
  }

  /// Opens the chat list, which joins the user's channel.
  Future<void> openChats() async {
    container.listen(chatsProvider, (_, __) {});
    await pumpEventQueue();
  }

  test("signing out leaves the user's channel", () async {
    await signIn('u1');
    await openChats();
    final channel = channels['u1']!.single;
    expect(channel.joined, isTrue);

    await container.read(authProvider.notifier).logout();
    await pumpEventQueue();

    expect(channel.disposed, isTrue);
  });

  test('another user gets their own channel; the old one is left', () async {
    await signIn('u1');
    await openChats();
    await container.read(authProvider.notifier).logout();
    await signIn('u2');
    await openChats();

    expect(channels['u1']!.single.disposed, isTrue);
    expect(channels['u2']!.single.joined, isTrue);
  });

  test('back from the background a dropped channel is joined again',
      () async {
    await signIn('u1');
    await openChats();
    final channel = channels['u1']!.single..drop();

    // To the background and back, state by state as Android reports it.
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(state);
    }
    await pumpEventQueue();

    expect(channel.reconnects, 1);
    // The chats again after the rejoin.
    expect(supabase.rpcCalls('get_chats'), hasLength(2));
  });
}

extension<T> on T {
  /// Runs [action] on this and returns it.
  T let(void Function(T) action) {
    action(this);
    return this;
  }
}
