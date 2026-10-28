import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';
import 'package:buildflow/features/team/domain/member_search.dart';
import 'package:flutter_test/flutter_test.dart';

Member _member(String name, UserRole role) => Member(
      id: 'member-$name',
      userId: 'user-$name',
      name: name,
      email: '$name@buildflow.kg',
      role: role,
      companyId: 'company-1',
    );

/// The matched parts of [name], e.g. `['Асан']`.
List<String>? _matched(String name, String query) => matchName(name, query)
    ?.map((r) => name.substring(r.start, r.end))
    .toList();

void main() {
  group('matchName', () {
    test('ignores case', () {
      expect(_matched('Бакыт Касымов', 'БАКЫТ'), ['Бакыт']);
      expect(_matched('Бакыт Касымов', 'бАкЫт'), ['Бакыт']);
    });

    test('matches the start of any word', () {
      expect(_matched('Бакыт Асанов', 'асан'), ['Асан']);
      expect(_matched('Асан Бекович', 'асан'), ['Асан']);
      expect(_matched('Айгуль Абдыраева-Асанова', 'асан'), ['Асан']);
    });

    test('does not match inside a word', () {
      expect(matchName('Бакыт Асанов', 'сан'), isNull);
      expect(matchName('Бакыт Касымов', 'ымов'), isNull);
    });

    test('treats ё as е both ways', () {
      expect(_matched('Пётр Семёнов', 'семен'), ['Семён']);
      expect(_matched('Петр Семенов', 'сёмен'), ['Семен']);
    });

    test('finds ң, ө, ү by themselves and by н, о, у', () {
      expect(_matched('Үмүт Өмүрбеков', 'үмүт'), ['Үмүт']);
      expect(_matched('Үмүт Өмүрбеков', 'умут'), ['Үмүт']);
      expect(_matched('Үмүт Өмүрбеков', 'өмүр'), ['Өмүр']);
      expect(_matched('Үмүт Өмүрбеков', 'омур'), ['Өмүр']);
      expect(_matched('Мөңкө Таңатаров', 'таңа'), ['Таңа']);
      expect(_matched('Мөңкө Таңатаров', 'тана'), ['Таңа']);
    });

    test('reads a Latin query as Cyrillic', () {
      expect(_matched('Бакыт Касымов', 'bakyt'), ['Бакыт']);
      expect(_matched('Бакыт Касымов', 'Kasymov'), ['Касымов']);
      expect(_matched('Данияр Жумабеков', 'daniyar'), ['Данияр']);
      expect(_matched('Данияр Жумабеков', 'zhumabekov'), ['Жумабеков']);
      expect(_matched('Данияр Жумабеков', 'jumabekov'), ['Жумабеков']);
      expect(_matched('Эрлан Токтосунов', 'erlan'), ['Эрлан']);
      expect(_matched('Айбек Чынгызов', 'aibek'), ['Айбек']);
      expect(_matched('Айбек Чынгызов', 'aybek'), ['Айбек']);
      expect(_matched('Айбек Чынгызов', 'chyngyz'), ['Чынгыз']);
      expect(_matched('Үмүт Өмүрбеков', 'ömür'), ['Өмүр']);
    });

    test('needs every word of the query to match a word', () {
      expect(_matched('Бакыт Касымов', 'бак кас'), ['Бак', 'Кас']);
      expect(_matched('Бакыт Касымов', 'кас бак'), ['Бак', 'Кас']);
      expect(matchName('Бакыт Касымов', 'бак асан'), isNull);
    });

    test('returns no ranges for a blank query', () {
      expect(matchName('Бакыт Касымов', ''), isEmpty);
      expect(matchName('Бакыт Касымов', '   '), isEmpty);
    });

    test('returns null when nothing matches', () {
      expect(matchName('Бакыт Касымов', 'нурлан'), isNull);
      expect(matchName('Бакыт Касымов', 'zzz'), isNull);
    });
  });

  group('searchMembers', () {
    final members = [
      _member('Асан Бекович', UserRole.owner),
      _member('Бакыт Касымов', UserRole.foreman),
      _member('Азамат Асанов', UserRole.worker),
      _member('Нурлан Абдыраев', UserRole.worker),
    ];

    List<String> names(List<MemberMatch> matches) =>
        [for (final m in matches) m.member.name];

    test('finds members by any word, sorted by name', () {
      expect(
        names(searchMembers(members, 'асан')),
        ['Азамат Асанов', 'Асан Бекович'],
      );
    });

    test('narrows by role', () {
      expect(
        names(searchMembers(members, 'асан', role: UserRole.worker)),
        ['Азамат Асанов'],
      );
    });

    test('lists the whole role for a query shorter than the minimum', () {
      expect(
        names(searchMembers(members, 'а', role: UserRole.worker)),
        ['Азамат Асанов', 'Нурлан Абдыраев'],
      );
    });

    test('returns nothing when nobody matches', () {
      expect(searchMembers(members, 'zzzz'), isEmpty);
    });
  });
}
