import 'dart:convert';

import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/chat/domain/entities/chat.dart';
import 'package:buildflow/features/chat/domain/entities/chat_enums.dart';
import 'package:buildflow/features/chat/domain/entities/message.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
import 'package:buildflow/features/team/domain/entities/invite_code.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('User entity', () {
    test('fromJson and toJson round-trip', () {
      const user = User(
        id: 'u1',
        email: 'test@test.com',
        name: 'Test',
        role: UserRole.owner,
        companyId: 'c1',
      );
      final json = user.toJson();
      final restored = User.fromJson(json);
      expect(restored, user);
    });

    test('UserRole.isOwner works', () {
      expect(UserRole.owner.isOwner, isTrue);
      expect(UserRole.foreman.isOwner, isFalse);
    });
  });

  group('Project entity', () {
    test('fromJson and toJson round-trip', () {
      const project = Project(
        id: 'p1',
        name: 'Test Project',
        address: 'Test St 1',
        status: ProjectStatus.active,
        companyId: 'c1',
        foremanIds: ['f1', 'f2'],
      );
      final json = project.toJson();
      final restored = Project.fromJson(json);
      expect(restored, project);
    });

    test('copyWith works', () {
      const project = Project(
        id: 'p1',
        name: 'Old Name',
        address: 'Addr',
        status: ProjectStatus.active,
        companyId: 'c1',
      );
      final updated = project.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.id, 'p1');
    });

    test('ProjectStatus.isActive works', () {
      expect(ProjectStatus.active.isActive, isTrue);
      expect(ProjectStatus.paused.isActive, isFalse);
      expect(ProjectStatus.finished.isActive, isFalse);
    });
  });

  group('Member entity', () {
    test('fromJson and toJson round-trip', () {
      const member = Member(
        id: 'm1',
        userId: 'u1',
        name: 'Test',
        email: 'test@test.com',
        role: UserRole.foreman,
        companyId: 'c1',
        assignedProjectIds: ['p1'],
      );
      final json = member.toJson();
      final restored = Member.fromJson(json);
      expect(restored, member);
    });
  });

  group('Report entity', () {
    test('fromJson and toJson round-trip', () {
      final now = DateTime(2024, 6, 15, 10, 30);
      final report = Report(
        id: 'r1',
        projectId: 'p1',
        projectName: 'Test',
        authorId: 'u1',
        authorName: 'Author',
        text: 'Report text',
        photos: [
          const ReportPhoto(id: 'ph1', url: 'fake:test'),
        ],
        createdAt: now,
      );
      final json = report.toJson();
      final restored = Report.fromJson(json);
      expect(restored, report);
    });

    test('nested photos survive a JSON string round-trip', () {
      final report = Report(
        id: 'r1',
        projectId: 'p1',
        projectName: 'Test',
        authorId: 'u1',
        authorName: 'Author',
        text: 'Report text',
        photos: [
          const ReportPhoto(id: 'ph1', url: 'fake:test'),
          ReportPhoto(
            id: 'ph2',
            url: 'https://x/2.jpg',
            thumbnailUrl: 'https://x/2s.jpg',
            takenAt: DateTime.utc(2024, 6, 15, 4, 12),
          ),
        ],
        createdAt: DateTime(2024, 6, 15, 10, 30),
      );
      final json = report.toJson();
      expect(json['photos'], everyElement(isA<Map<String, dynamic>>()));

      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(Report.fromJson(decoded), report);
      final photos = (decoded['photos'] as List).cast<Map<String, dynamic>>();
      expect(photos.last['takenAt'], '2024-06-15T04:12:00.000Z');
      expect(photos.first['takenAt'], isNull);
    });
  });

  group('times from the server', () {
    final moment = DateTime.utc(2026, 11, 4, 5, 47);

    for (final text in const [
      '2026-11-04T05:47:00Z',
      '2026-11-04T05:47:00+00:00',
      '2026-11-04T11:47:00+06:00',
      '2026-11-04T00:47:00-05:00',
    ]) {
      test('$text is one moment in UTC in every entity', () {
        final report = Report.fromJson({
          'id': 'r',
          'projectId': 'p',
          'projectName': 'Объект',
          'authorId': 'u',
          'authorName': 'Имя',
          'text': '',
          'photos': <Object>[],
          'createdAt': text,
        });
        final photo = ReportPhoto.fromJson({
          'id': 'ph',
          'url': 'fake:x',
          'takenAt': text,
        });
        final message = Message.fromJson({
          'id': 'm',
          'clientId': 'm',
          'chatId': 'c',
          'senderId': 'u',
          'kind': MessageKind.text.name,
          'createdAt': text,
        });
        final chat = Chat.fromJson({
          'id': 'c',
          'type': ChatType.direct.name,
          'participantIds': <String>[],
          'updatedAt': text,
        });
        final invite = InviteCode.fromJson({
          'code': 'ABC234',
          'companyId': 'co',
          'role': UserRole.worker.name,
          'createdAt': text,
          'expiresAt': text,
        });

        for (final time in [
          report.createdAt,
          photo.takenAt!,
          message.createdAt,
          chat.updatedAt,
          invite.createdAt,
          invite.expiresAt!,
        ]) {
          expect(time, moment);
          expect(time.isUtc, isTrue);
        }
      });
    }
  });
}
