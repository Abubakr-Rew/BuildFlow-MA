// End to end against the local Supabase: the real repositories over HTTP
// and the Realtime WebSocket. Not part of `flutter test` (test/ only); run
// it on a reset stack (README, «Запуск с сервером на компьютере»):
//
//   npx supabase@2.122.0 db reset
//   node tool/local_env.mjs
//   flutter test integration/supabase --dart-define-from-file=env/local.env
@Tags(['supabase'])
library;

import 'dart:async';
import 'dart:io';

import 'package:buildflow/core/audio/voice_note.dart';
import 'package:buildflow/core/error/failures.dart';
import 'package:buildflow/core/photos/compressed_photo.dart';
import 'package:buildflow/core/remote_files/remote_files.dart';
import 'package:buildflow/core/remote_files/storage_ref.dart';
import 'package:buildflow/core/storage/local_storage.dart';
import 'package:buildflow/core/supabase/supabase_gateway.dart';
import 'package:buildflow/core/supabase/supabase_uploads.dart';
import 'package:buildflow/features/auth/data/supabase_auth_repository.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/chat/data/chat_events.dart';
import 'package:buildflow/features/chat/data/supabase_chat_repository.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/projects/data/supabase_project_repository.dart';
import 'package:buildflow/features/projects/domain/entities/project_changes.dart';
import 'package:buildflow/features/reports/data/supabase_report_repository.dart';
import 'package:buildflow/features/team/data/supabase_team_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

/// The seeded «Ала-Тоо» of foreman1@ (supabase/seed.sql).
const _alaToo = 'b0000000-0000-4000-8000-000000000001';

const _wait = Duration(seconds: 15);

/// One person on their own phone: a client, its session and repositories.
class _Phone {
  _Phone() {
    client = SupabaseClient(
      _url,
      _key,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    gateway = SupabaseGateway(client, url: _url, anonKey: _key);
    auth = SupabaseAuthRepository(
      gateway: gateway,
      localStorage: LocalStorageService(),
    );
    projects = SupabaseProjectRepository(gateway: gateway);
    team = SupabaseTeamRepository(gateway: gateway);
    uploads = SupabaseUploads(gateway);
    reports = SupabaseReportRepository(gateway: gateway, uploads: uploads);
  }

  late final SupabaseClient client;
  late final SupabaseGateway gateway;
  late final SupabaseAuthRepository auth;
  late final SupabaseProjectRepository projects;
  late final SupabaseTeamRepository team;
  late final SupabaseUploads uploads;
  late final SupabaseReportRepository reports;
  SupabaseChatRepository? _chat;
  SupabaseChatEvents? events;

  /// The chats of the signed-in user, with their channel joined.
  Future<SupabaseChatRepository> chat(String userId) async {
    if (_chat case final chat?) return chat;
    final events = this.events = SupabaseChatEvents(client, userId: userId);
    final chat = _chat = SupabaseChatRepository(
      gateway: gateway,
      uploads: uploads,
      userId: userId,
      events: events,
    );
    // Listening joins the channel.
    unawaited(chat.watchChats().first);
    await _until(() => events.isJoined, 'channel of $userId joined');
    return chat;
  }

  Future<void> dispose() async {
    await _chat?.dispose();
    await gateway.dispose();
    await client.dispose();
  }
}

Future<void> _until(bool Function() done, String what) async {
  final deadline = DateTime.now().add(_wait);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting: $what');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

Future<List<Message>> _messagesWhere(
  Stream<List<Message>> stream,
  bool Function(List<Message>) test,
) =>
    stream.firstWhere(test).timeout(_wait);

void main() {
  late Directory dir;
  final phones = <_Phone>[];

  setUpAll(() async {
    if (_url.isEmpty || _key.isEmpty) {
      fail('Run with --dart-define-from-file=env/local.env');
    }
    // On the VM there is no platform storage; the profile cache and the
    // device id live in memory. (integration/ isn't a test directory for
    // the analyzer.)
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('supabase_flow');
  });
  tearDownAll(() async {
    for (final phone in phones) {
      await phone.dispose();
    }
    await dir.delete(recursive: true);
  });

  _Phone phone() => _Phone()..let(phones.add);

  File file(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  final stamp = DateTime.now().millisecondsSinceEpoch;

  test('director, invite, join, project chat with a photo and a voice note, '
      'report, removal', () async {
    // ── The director signs in and invites a worker ───────────
    final director = phone();
    final owner = (await director.auth.login(
      email: 'owner@buildflow.kg',
      password: '123456',
    ))
        .value;
    expect(owner.role, UserRole.owner);

    final project = (await director.projects.createProject(
      name: 'Интеграция $stamp',
      address: 'ул. Тестовая 1',
    ))
        .value;
    final invite =
        (await director.team.generateInviteCode(role: UserRole.worker)).value;
    expect(invite.code, hasLength(6));

    // ── The worker joins with the code on their phone ────────
    final builder = phone();
    final worker = (await builder.auth.joinWithInviteCode(
      email: 'int-$stamp@buildflow.kg',
      password: '123456',
      name: 'Интеграционный Строитель',
      inviteCode: invite.code,
    ))
        .value;
    expect(worker.role, UserRole.worker);
    expect(worker.companyId, owner.companyId);
    expect(
      (await builder.auth.joinWithInviteCode(
        email: 'int2-$stamp@buildflow.kg',
        password: '123456',
        name: 'Второй',
        inviteCode: invite.code,
      ))
          .failure
          .code,
      FailureCode.invalidInviteCode,
      reason: 'the code is spent',
    );
    final members = (await director.team.getMembers()).value;
    expect(members.map((m) => m.userId), contains(worker.id));

    // ── The director puts them on the project ────────────────
    await director.projects.updateProject(
      project.id,
      ProjectChanges(workerIds: [worker.id]),
    );
    final seen = (await builder.projects.getProjects()).value;
    expect(seen.map((p) => p.id), [project.id]);

    // ── Both open the project chat ───────────────────────────
    final ownerChat = await director.chat(owner.id);
    final workerChat = await builder.chat(worker.id);
    final chats = await workerChat
        .watchChats()
        .firstWhere((list) => list.any((c) => c.projectId == project.id))
        .timeout(_wait);
    final chatId = chats.firstWhere((c) => c.projectId == project.id).id;

    final workerSees = workerChat.watchMessages(chatId).asBroadcastStream();
    final ownerSees = ownerChat.watchMessages(chatId).asBroadcastStream();
    await workerSees.first.timeout(_wait);
    await ownerSees.first.timeout(_wait);

    // The director writes; the worker gets it over Realtime.
    final arriving = _messagesWhere(
      workerSees,
      (list) => list.any((m) => m.text == 'Бетон привезли $stamp'),
    );
    final sent = await ownerChat.send(
      chatId,
      clientId: '00000000-0000-4000-8000-${stamp.toString().padLeft(12, '0').substring(0, 12)}',
      text: 'Бетон привезли $stamp',
    );
    expect(sent.isSuccess, isTrue);
    await arriving;

    // The worker answers with a photo; the director gets it and can
    // download it through a signed link.
    final jpeg = List<int>.generate(2048, (i) => i % 251);
    final photo = file('photo.jpg', jpeg);
    final uploaded = (await workerChat.uploadPhoto(
      CompressedPhoto(path: photo.path, width: 1600, height: 1200, bytes: jpeg.length),
    ))
        .value;
    final photoArrives = _messagesWhere(
      ownerSees,
      (list) => list.any((m) => m.kind == MessageKind.photo && m.text == 'Армирование'),
    );
    expect(
      (await workerChat.send(
        chatId,
        clientId: '10000000-0000-4000-8000-${stamp.toString().padLeft(12, '0').substring(0, 12)}',
        text: 'Армирование',
        attachmentIds: [uploaded.id],
      ))
          .isSuccess,
      isTrue,
    );
    final photoMessage = (await photoArrives)
        .lastWhere((m) => m.kind == MessageKind.photo);
    final attachment = photoMessage.attachments.single;
    expect(attachment.width, 1600);
    final ownerFiles = RemoteFiles(
      gateway: director.gateway,
      cacheDir: () async => '${dir.path}/owner',
    );
    final downloaded = (await ownerFiles.localPath(StorageRef.tryParse(attachment.url)!)).value;
    expect(File(downloaded).readAsBytesSync(), jpeg);

    // And a voice note.
    final voice = file('note.m4a', List<int>.filled(4000, 7));
    final note = VoiceNote(
      path: voice.path,
      duration: const Duration(milliseconds: 4200),
      waveform: List<int>.generate(40, (i) => i * 2),
    );
    final voiceAttachment = (await workerChat.uploadVoice(note)).value;
    final voiceArrives = _messagesWhere(
      ownerSees,
      (list) => list.any((m) => m.kind == MessageKind.voice),
    );
    await workerChat.send(
      chatId,
      clientId: '20000000-0000-4000-8000-${stamp.toString().padLeft(12, '0').substring(0, 12)}',
      attachmentIds: [voiceAttachment.id],
    );
    final voiceMessage =
        (await voiceArrives).lastWhere((m) => m.kind == MessageKind.voice);
    expect(voiceMessage.attachments.single.durationMs, 4200);
    expect(voiceMessage.listened, isFalse);
    expect((await ownerChat.markListened(chatId, messageId: voiceMessage.id)).isSuccess, isTrue);

    // The director reading turns the worker's messages read.
    final readArrives = _messagesWhere(
      workerSees,
      (list) => list.any((m) => m.id == voiceMessage.id && m.status == MessageStatus.read),
    );
    await ownerChat.markRead(chatId, upTo: voiceMessage.id);
    await readArrives;

    // ── A foreman reports with a photo; the director sees it ─
    final foremanPhone = phone();
    await foremanPhone.auth.login(email: 'foreman1@buildflow.kg', password: '123456');
    final reportPhoto = file('report.jpg', List<int>.filled(1500, 3));
    final report = (await foremanPhone.reports.submitReport(
      projectId: _alaToo,
      projectName: '',
      authorId: '',
      authorName: '',
      text: 'Интеграционный отчёт $stamp',
      photos: [
        CompressedPhoto(
          path: reportPhoto.path,
          width: 1200,
          height: 1600,
          bytes: 1500,
          takenAt: DateTime.utc(2026, 11, 2, 6),
        ),
      ],
    ))
        .value;
    final reports = (await director.reports.getReports()).value;
    final seenReport = reports.firstWhere((r) => r.id == report.id);
    // The server's time arrives as a UTC moment; screens make it local.
    expect(seenReport.createdAt.isUtc, isTrue);
    expect(seenReport.photos.single.takenAt, DateTime.utc(2026, 11, 2, 6));
    expect(seenReport.photos.single.url, startsWith('storage:photos/'));
    expect(
      (await ownerFiles.localPath(StorageRef.tryParse(seenReport.photos.single.url)!)).isSuccess,
      isTrue,
    );

    // ── The director removes the worker ──────────────────────
    final ended = builder.gateway.sessionEnded.first;
    expect((await director.team.removeMember(worker.id)).isSuccess, isTrue);
    // Their next request finds the account removed and ends the session.
    expect(
      (await builder.projects.getProjects()).failure.code,
      FailureCode.sessionExpired,
    );
    expect((await ended.timeout(_wait)).code, FailureCode.sessionExpired);
    expect(builder.client.auth.currentSession, isNull);
    // And they can't sign in again.
    expect(
      (await builder.auth.login(email: 'int-$stamp@buildflow.kg', password: '123456'))
          .failure
          .code,
      FailureCode.accountDisabled,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('wrong password and unknown invite code', () async {
    final someone = phone();
    expect(
      (await someone.auth.login(email: 'owner@buildflow.kg', password: 'nope')).failure.code,
      FailureCode.invalidCredentials,
    );
    expect(
      (await someone.auth.joinWithInviteCode(
        email: 'nobody-$stamp@buildflow.kg',
        password: '123456',
        name: 'Никто',
        inviteCode: 'ZZZZZZ',
      ))
          .failure
          .code,
      FailureCode.invalidInviteCode,
    );
  });

  test('a session survives a restart: a new client recovers it', () async {
    final first = phone();
    await first.auth.login(email: 'worker1@buildflow.kg', password: '123456');
    final saved = first.client.auth.currentSession!;

    // What SecureSessionStorage keeps is what supabase_flutter recovers.
    final second = phone();
    await second.client.auth.recoverSession(
      '{"access_token":"${saved.accessToken}","refresh_token":"${saved.refreshToken}",'
      '"token_type":"bearer","expires_in":${saved.expiresIn},"expires_at":${saved.expiresAt},'
      '"user":{"id":"${saved.user.id}","aud":"authenticated","app_metadata":{},'
      '"user_metadata":{},"created_at":"${saved.user.createdAt}"}}',
    );
    final restored = (await second.auth.restoreSession()).value;
    expect(restored.email, 'worker1@buildflow.kg');
  });
}

extension<T> on T {
  T let(void Function(T) action) {
    action(this);
    return this;
  }
}
