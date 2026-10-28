import 'package:buildflow/features/auth/domain/entities/user_role.dart';
import 'package:buildflow/features/team/domain/entities/member.dart';

/// Shorter queries don't search: the screen shows recent people instead,
/// and the server returns nothing (docs/api-contract.md, `GET /team/members`).
const minPeopleSearchLength = 2;

/// Half-open range `[start, end)` of matched characters in a name.
typedef MatchRange = ({int start, int end});

/// A member found by [searchMembers] with the matched parts of the name.
typedef MemberMatch = ({Member member, List<MatchRange> ranges});

/// Where [query] matches [name], or `null` if it doesn't.
///
/// Every word of the query must match the start of some word of the name
/// («асан» finds «Бакыт Асанов», «сан» doesn't), case-insensitively, with
/// ё = е, Kyrgyz ң/ө/ү = н/о/у and a Latin query read as Cyrillic
/// («bakyt» → «Бакыт»). A blank query matches every name with no ranges.
///
/// The server applies the same rules (docs/api-contract.md).
List<MatchRange>? matchName(String name, String query) {
  final folded = _fold(name);
  final tokens = _fold(_latinToCyrillic(query.toLowerCase()))
      .split(_separators)
      .where((t) => t.isNotEmpty);

  final wordStarts = [
    for (var i = 0; i < folded.length; i++)
      if (!_isSeparator(folded[i]) && (i == 0 || _isSeparator(folded[i - 1])))
        i,
  ];

  final ranges = <MatchRange>[];
  for (final token in tokens) {
    final start = wordStarts
        .where((i) => folded.startsWith(token, i))
        .firstOrNull;
    if (start == null) return null;
    ranges.add((start: start, end: start + token.length));
  }
  return _merge(ranges);
}

/// [members] matching [query] (see [matchName]) and [role], by name.
/// A [query] shorter than [minPeopleSearchLength] filters by role only.
List<MemberMatch> searchMembers(
  Iterable<Member> members,
  String query, {
  UserRole? role,
}) {
  final q = query.trim();
  final effective = q.length < minPeopleSearchLength ? '' : q;
  final matches = <MemberMatch>[
    for (final member in members)
      if (role == null || member.role == role)
        if (matchName(member.name, effective) case final ranges?)
          (member: member, ranges: ranges),
  ]..sort((a, b) => a.member.name.compareTo(b.member.name));
  return matches;
}

// ── Normalization ────────────────────────────────────────────

final _separators = RegExp(r'[\s\-]+');

bool _isSeparator(String c) => _separators.hasMatch(c);

/// Letters that are compared as one. Besides ё/ң/ө/ү, folds the letters a
/// Latin query can't tell apart: «y» is both ы and й, «e» both е and э.
const _foldMap = {
  'ё': 'е',
  'э': 'е',
  'ң': 'н',
  'ө': 'о',
  'ү': 'у',
  'й': 'и',
  'ы': 'и',
};

/// Lower case plus [_foldMap], one character for one, so positions in the
/// result are positions in [s].
String _fold(String s) {
  final out = StringBuffer();
  for (final unit in s.codeUnits) {
    final c = String.fromCharCode(unit);
    final lower = c.toLowerCase();
    final one = lower.length == 1 ? lower : c;
    out.write(_foldMap[one] ?? one);
  }
  return out.toString();
}

/// Longest first: «shch» before «sh» before «s».
const _latin = [
  ('shch', 'щ'),
  ('sh', 'ш'),
  ('ch', 'ч'),
  ('zh', 'ж'),
  ('kh', 'х'),
  ('ts', 'ц'),
  ('ya', 'я'),
  ('yu', 'ю'),
  ('yo', 'ё'),
  ('ye', 'е'),
  ('a', 'а'),
  ('b', 'б'),
  ('c', 'к'),
  ('d', 'д'),
  ('e', 'е'),
  ('f', 'ф'),
  ('g', 'г'),
  ('h', 'х'),
  ('i', 'и'),
  ('j', 'ж'),
  ('k', 'к'),
  ('l', 'л'),
  ('m', 'м'),
  ('n', 'н'),
  ('o', 'о'),
  ('ö', 'ө'),
  ('p', 'п'),
  ('q', 'к'),
  ('r', 'р'),
  ('s', 'с'),
  ('t', 'т'),
  ('u', 'у'),
  ('ü', 'ү'),
  ('v', 'в'),
  ('w', 'в'),
  ('x', 'кс'),
  ('y', 'ы'),
  ('z', 'з'),
];

/// Reads Latin letters of a lower-case [s] as Cyrillic; the rest stays.
String _latinToCyrillic(String s) {
  final out = StringBuffer();
  var i = 0;
  outer:
  while (i < s.length) {
    for (final (latin, cyrillic) in _latin) {
      if (s.startsWith(latin, i)) {
        out.write(cyrillic);
        i += latin.length;
        continue outer;
      }
    }
    out.write(s[i]);
    i++;
  }
  return out.toString();
}

/// Sorted, with overlapping ranges joined.
List<MatchRange> _merge(List<MatchRange> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <MatchRange>[];
  for (final r in sorted) {
    final last = merged.lastOrNull;
    if (last != null && r.start <= last.end) {
      merged[merged.length - 1] = (
        start: last.start,
        end: r.end > last.end ? r.end : last.end,
      );
    } else {
      merged.add(r);
    }
  }
  return merged;
}
