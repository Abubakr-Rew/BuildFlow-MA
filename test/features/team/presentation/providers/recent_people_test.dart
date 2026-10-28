import 'package:buildflow/features/auth/domain/entities/user.dart';
import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:buildflow/features/team/presentation/providers/team_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

// The signed-in user, switchable without going through AuthNotifier.
final _user = NotifierProvider<_UserNotifier, User?>(_UserNotifier.new);

class _UserNotifier extends Notifier<User?> {
  @override
  User? build() => _owner;

  User? get user => state;
  set user(User? value) => state = value;
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_user)),
      ],
    );
    addTearDown(container.dispose);
  });

  List<String> recent() => container.read(recentPeopleProvider);
  void open(String id) => container.read(recentPeopleProvider.notifier).add(id);

  group('RecentPeopleNotifier', () {
    test('starts empty', () {
      expect(recent(), isEmpty);
    });

    test('puts the last opened person first', () {
      open('member-2');
      open('member-3');
      expect(recent(), ['member-3', 'member-2']);
    });

    test('moves a person opened again to the top without a duplicate', () {
      open('member-2');
      open('member-3');
      open('member-2');
      expect(recent(), ['member-2', 'member-3']);
    });

    test('keeps the last five', () {
      for (var i = 1; i <= 7; i++) {
        open('member-$i');
      }
      expect(recent(), [
        'member-7',
        'member-6',
        'member-5',
        'member-4',
        'member-3',
      ]);
    });

    test('is cleared when the user changes', () {
      // Keep the provider alive, as the search screen does.
      final sub = container.listen(recentPeopleProvider, (_, __) {});
      addTearDown(sub.close);

      open('member-2');
      container.read(_user.notifier).user = _foreman;
      expect(recent(), isEmpty);
    });
  });
}
