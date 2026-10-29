import 'package:buildflow/app/theme/app_theme.dart';
import 'package:buildflow/core/widgets/photo_viewer.dart';
import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/auth/presentation/screens/join_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/login_screen.dart';
import 'package:buildflow/features/auth/presentation/screens/register_screen.dart';
import 'package:buildflow/features/chat/data/fake_chat_store.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:buildflow/features/chat/presentation/screens/chat_screen.dart';
import 'package:buildflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_detail_screen.dart';
import 'package:buildflow/features/projects/presentation/screens/project_list_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/new_report_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_detail_screen.dart';
import 'package:buildflow/features/reports/presentation/screens/report_list_screen.dart';
import 'package:buildflow/features/team/presentation/screens/people_search_screen.dart';
import 'package:buildflow/features/team/presentation/screens/team_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

const _owner = User(
  id: 'user-owner-1',
  email: 'owner@buildflow.kg',
  name: 'Асан Бекович',
  role: UserRole.owner,
  companyId: 'company-1',
);

const _foreman = User(
  id: 'user-foreman-1',
  email: 'foreman1@buildflow.kg',
  name: 'Бакыт Касымов',
  role: UserRole.foreman,
  companyId: 'company-1',
);

/// Every screen renders on the seeded fake data in both themes without
/// layout overflows or exceptions.
void main() {
  final screens = <String, (Widget, User?)>{
    'login': (const LoginScreen(), null),
    'register': (const RegisterScreen(), null),
    'join': (const JoinScreen(), null),
    'projects': (const ProjectListScreen(), _owner),
    'project': (const ProjectDetailScreen(projectId: 'project-1'), _owner),
    'project (foreman)': (
      const ProjectDetailScreen(projectId: 'project-2'),
      _foreman,
    ),
    'new report': (
      const NewReportScreen(initialProjectId: 'project-1'),
      _foreman,
    ),
    'reports': (const ReportListScreen(), _owner),
    'report': (const ReportDetailScreen(reportId: 'report-3'), _owner),
    'team': (const TeamListScreen(), _owner),
    'people search': (const PeopleSearchScreen(), _owner),
    'chats': (const ChatListScreen(), _owner),
    'chats (foreman)': (const ChatListScreen(), _foreman),
    'project chat': (const ChatScreen(chatId: 'chat-project-1'), _owner),
    'direct chat': (
      ChatScreen(
        chatId: FakeChatStore.directChatId(_owner.id, _foreman.id),
      ),
      _foreman,
    ),
    'people search (foreman)': (const PeopleSearchScreen(), _foreman),
    'profile': (const ProfileScreen(), _owner),
    'photo viewer': (
      const PhotoViewer(
        initialIndex: 1,
        photos: [
          ViewerPhoto(url: 'fake:a', author: 'Бакыт Касымов', time: '11:42'),
          ViewerPhoto(
            url: 'fake:b',
            caption: 'Залили плиту 8-го этажа',
            author: 'Бакыт Касымов',
            time: 'Снято 11:42',
            warning: 'Снято не сегодня',
          ),
        ],
      ),
      null,
    ),
  };

  for (final (themeName, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    for (final MapEntry(key: name, value: (screen, user)) in screens.entries) {
      testWidgets('$name renders in the $themeName theme', (tester) async {
        await pumpTestApp(
          tester,
          screen,
          theme: theme,
          overrides: [
            if (user != null) currentUserProvider.overrideWithValue(user),
          ],
        );
        // Projects, then reports and members, each with fake latency.
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
