import 'models.dart';

/// Short school names people type, and what NEIS calls them.
const _suffixes = <(String, String)>[
  ('여고', '여자고등학교'),
  ('여중', '여자중학교'),
  ('공고', '공업고등학교'),
  ('상고', '상업고등학교'),
  ('과고', '과학고등학교'),
  ('외고', '외국어고등학교'),
  ('예고', '예술고등학교'),
  ('고', '고등학교'),
  ('중', '중학교'),
  ('초', '초등학교'),
];

/// The full NEIS spelling of a short school name such as `서울고` or
/// `경덕여고`, or `null` when [query] is not one.
///
/// ```dart
/// expandNeisSchoolName('경덕여고'); // '경덕여자고등학교'
/// ```
String? expandNeisSchoolName(String query) {
  final text = _normalize(query);
  for (final (short, full) in _suffixes) {
    if (text.length > short.length && text.endsWith(short)) {
      return text.substring(0, text.length - short.length) + full;
    }
  }
  return null;
}

/// Sorts [schools] by how well their name matches [query], best first.
///
/// An exact name comes first, then the full spelling of a short name (`서울고`
/// for 서울고등학교), then names starting with the query, then names
/// containing it, then the rest. Within each group, names closer to the query
/// come first. Spaces are ignored.
List<NeisSchool> rankNeisSchools(String query, Iterable<NeisSchool> schools) {
  final text = _normalize(query);
  final expanded = expandNeisSchoolName(query);
  int tier(String name) {
    if (name == text) return 0;
    if (name == expanded) return 1;
    if (name.startsWith(text) ||
        (expanded != null && name.startsWith(expanded))) {
      return 2;
    }
    if (name.contains(text) || (expanded != null && name.contains(expanded))) {
      return 3;
    }
    return 4;
  }

  final scored = [
    for (final school in schools)
      (
        school: school,
        tier: tier(_normalize(school.name)),
        distance: _distance(_normalize(school.name), expanded ?? text),
      ),
  ];
  scored.sort((a, b) {
    for (final order in [
      a.tier.compareTo(b.tier),
      a.distance.compareTo(b.distance),
      a.school.name.compareTo(b.school.name),
    ]) {
      if (order != 0) return order;
    }
    return 0;
  });
  return [for (final entry in scored) entry.school];
}

String _normalize(String text) => text.replaceAll(RegExp(r'\s+'), '');

/// Levenshtein distance over UTF-16 units, enough for Hangul names.
int _distance(String a, String b) {
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = [
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
