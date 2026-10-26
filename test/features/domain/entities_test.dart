import 'dart:convert';

import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/projects/domain/entities/project.dart';
import 'package:buildflow/features/projects/domain/entities/project_status.dart';
import 'package:buildflow/features/reports/domain/entities/report.dart';
import 'package:buildflow/features/reports/domain/entities/report_photo.dart';
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
        photos: const [
          ReportPhoto(id: 'ph1', url: 'fake:test'),
          ReportPhoto(id: 'ph2', url: 'https://x/2.jpg', thumbnailUrl: 'https://x/2s.jpg'),
        ],
        createdAt: DateTime(2024, 6, 15, 10, 30),
      );
      final json = report.toJson();
      expect(json['photos'], everyElement(isA<Map<String, dynamic>>()));

      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      expect(Report.fromJson(decoded), report);
    });
  });
}
