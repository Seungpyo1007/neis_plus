import 'values.dart';

/// Meal of the day, `MMEAL_SC_CODE` in NEIS.
enum NeisMealType {
  /// 조식, code 1.
  breakfast(1, '조식'),

  /// 중식, code 2.
  lunch(2, '중식'),

  /// 석식, code 3.
  dinner(3, '석식');

  const NeisMealType(this.code, this.label);

  /// `MMEAL_SC_CODE` value.
  final int code;

  /// Korean name NEIS uses in `MMEAL_SC_NM`.
  final String label;

  /// The type with [code], or `null`.
  static NeisMealType? fromCode(Object? code) {
    final number = neisInt(code);
    for (final type in values) {
      if (type.code == number) return type;
    }
    return null;
  }

  /// The type named [label], such as 중식, or `null`.
  static NeisMealType? fromLabel(String? label) {
    final text = label?.trim();
    for (final type in values) {
      if (type.label == text) return type;
    }
    return null;
  }
}

/// The 19 allergens NEIS numbers in meal listings.
enum NeisAllergen {
  /// 1. 난류.
  eggs(1, '난류'),

  /// 2. 우유.
  milk(2, '우유'),

  /// 3. 메밀.
  buckwheat(3, '메밀'),

  /// 4. 땅콩.
  peanuts(4, '땅콩'),

  /// 5. 대두.
  soybeans(5, '대두'),

  /// 6. 밀.
  wheat(6, '밀'),

  /// 7. 고등어.
  mackerel(7, '고등어'),

  /// 8. 게.
  crab(8, '게'),

  /// 9. 새우.
  shrimp(9, '새우'),

  /// 10. 돼지고기.
  pork(10, '돼지고기'),

  /// 11. 복숭아.
  peach(11, '복숭아'),

  /// 12. 토마토.
  tomato(12, '토마토'),

  /// 13. 아황산류.
  sulfites(13, '아황산류'),

  /// 14. 호두.
  walnuts(14, '호두'),

  /// 15. 닭고기.
  chicken(15, '닭고기'),

  /// 16. 쇠고기.
  beef(16, '쇠고기'),

  /// 17. 오징어.
  squid(17, '오징어'),

  /// 18. 조개류, including 굴, 전복, and 홍합.
  shellfish(18, '조개류'),

  /// 19. 잣.
  pineNuts(19, '잣');

  const NeisAllergen(this.number, this.label);

  /// Number NEIS writes after a dish, as in `미역국 (5.6)`.
  final int number;

  /// Korean name.
  final String label;

  /// The allergen numbered [number], or `null` outside 1 to 19.
  static NeisAllergen? fromNumber(int number) =>
      number >= 1 && number <= values.length ? values[number - 1] : null;
}

/// One nutrient of a meal, from a `NTR_INFO` line such as
/// `탄수화물(g) : 86.8`.
class NeisNutrient {
  /// Creates a nutrient.
  const NeisNutrient(this.name, this.value, {this.unit});

  /// Nutrient name without the unit, such as 탄수화물.
  final String name;

  /// Amount per serving.
  final double value;

  /// Unit as published, such as `g`, `mg`, or `R.E`.
  final String? unit;

  @override
  bool operator ==(Object other) =>
      other is NeisNutrient &&
      other.name == name &&
      other.value == value &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(name, value, unit);

  @override
  String toString() => '$name $value${unit ?? ''}';
}

/// Where one ingredient comes from, from an `ORPLC_INFO` line such as
/// `쇠고기(종류) : 국내산(한우)`.
class NeisOrigin {
  /// Creates an entry.
  const NeisOrigin(this.ingredient, this.origin);

  /// Ingredient as published, such as `쇠고기(종류)` or `콩 가공품`.
  final String ingredient;

  /// Origin as published, such as `국내산(한우)`.
  final String origin;

  @override
  bool operator ==(Object other) =>
      other is NeisOrigin &&
      other.ingredient == ingredient &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(ingredient, origin);

  @override
  String toString() => '$ingredient: $origin';
}

/// Reads calories such as `664.5 Kcal`.
double? parseNeisCalories(String? text) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text ?? '');
  return match == null ? null : double.parse(match[1]!);
}

/// Reads `NTR_INFO` lines such as `탄수화물(g) : 86.8`, keyed by name.
///
/// Lines are separated by `<br/>` or line breaks. A line without a number is
/// skipped.
Map<String, NeisNutrient> parseNeisNutrients(String? text) {
  final nutrients = <String, NeisNutrient>{};
  for (final line in _splitLines(text)) {
    final colon = line.lastIndexOf(':');
    if (colon < 0) continue;
    final value = neisDouble(line.substring(colon + 1));
    if (value == null) continue;
    final label = line.substring(0, colon).trim();
    final unit = RegExp(r'^(.*?)\s*\(([^()]*)\)$').firstMatch(label);
    final name = unit == null ? label : unit[1]!.trim();
    if (name.isEmpty) continue;
    nutrients[name] = NeisNutrient(name, value, unit: unit?[2]!.trim());
  }
  return nutrients;
}

/// Reads `ORPLC_INFO` lines such as `쇠고기(종류) : 국내산(한우)`.
///
/// Only the first ` : ` separates the ingredient from its origin, since
/// schools write colons inside the origin too, as in `콩 가공품 : 콩:수입`.
/// Lines with no origin, such as the trailing `비고 : `, are skipped.
List<NeisOrigin> parseNeisOrigins(String? text) => [
  for (final line in _splitLines(text)) ?_origin(line),
];

NeisOrigin? _origin(String line) {
  final separator = RegExp(r'\s:\s?|\s?:\s').firstMatch(line);
  if (separator == null) return null;
  final ingredient = line.substring(0, separator.start).trim();
  final origin = line.substring(separator.end).trim();
  if (ingredient.isEmpty || origin.isEmpty) return null;
  return NeisOrigin(ingredient, origin);
}

Iterable<String> _splitLines(String? text) sync* {
  for (final line in (text ?? '').split(
    RegExp(r'<br\s*/?>|\n', caseSensitive: false),
  )) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) yield trimmed;
  }
}

/// Tags schools put in parentheses after a dish that say who or when it is
/// for, not what it is: `(가)`, `(과)`, `(친)` for an ingredient or campus
/// mark, `(자율)` for self-serve, `(점심)`, `(배식)`, and grade or level marks.
const _parenthesizedTags = {
  '가',
  '과',
  '친',
  '초',
  '중',
  '고',
  '수',
  '남',
  '여',
  '유아',
  '자율',
  '선택',
  '배식',
  '열량',
  '아침',
  '점심',
  '저녁',
  '조식',
  '중식',
  '석식',
  '완제품',
  '완조리',
};

/// Splits school markers off a dish name.
///
/// Schools decorate dish names with marks that are not part of the dish:
/// `*` and `@` for local or eco-friendly ingredients, a trailing `s`, `kh`, or
/// digit, a leading `o`, and tags in parentheses such as `(가)`, `(자율)`, or
/// `(점심)`. A leading `[…]` label such as `[기후동행식단]` is a marker too.
/// Parentheses that describe the dish, such as `(홍로)` or `(포도맛)`, stay.
///
/// Returns the cleaned name and the markers removed, in the order found.
({String name, List<String> markers}) splitNeisDishMarkers(String dish) {
  var name = dish.trim();
  final markers = <String>[];

  void take(RegExp pattern, {bool atEnd = true}) {
    while (true) {
      final match = pattern.firstMatch(name);
      if (match == null) return;
      final marker = match[1]!;
      markers.add(marker.trim());
      name = atEnd
          ? name.substring(0, match.start).trimRight()
          : name.substring(match.end).trimLeft();
      if (name.isEmpty) return;
    }
  }

  // Leading marks: [label], *, @, and a single lowercase letter glued to
  // Hangul, as in `o돼지불고기`. Uppercase pairs such as `LA갈비` stay.
  take(RegExp(r'^(\[[^\]]*\])\s*'), atEnd: false);
  take(RegExp(r'^([*@]+)\s*'), atEnd: false);
  take(RegExp(r'^([a-z])(?=[가-힣])'), atEnd: false);

  for (var pass = 0; pass < 4; pass++) {
    final before = name;
    take(RegExp(r'([*@]+)$'));
    // `(가)`, `(자율)`, `(친.생선)`: a known tag, optionally followed by a
    // dot and more.
    final paren = RegExp(r'\s*\(([^()]*)\)$').firstMatch(name);
    if (paren != null && _isTag(paren[1]!)) {
      markers.add('(${paren[1]})');
      name = name.substring(0, paren.start).trimRight();
    }
    // Latin letters or digits glued to the end of a Hangul or closing
    // parenthesis, as in `십곡밥s`, `배kh`, `깍두기1`, or `호박죽-1`.
    take(RegExp(r'(?<=[가-힣)])(-?[A-Za-z]{1,2}|-?\d{1,2})$'));
    // A separator left dangling once a tag is gone, as in `영양닭죽-(과)`.
    name = name.replaceFirst(RegExp(r'[\s\-/·~]+$'), '');
    if (name == before) break;
  }
  return (name: name.isEmpty ? dish.trim() : name, markers: markers);
}

bool _isTag(String content) {
  final text = content.trim();
  if (text.isEmpty) return false;
  if (_parenthesizedTags.contains(text)) return true;
  // Latin codes such as `(m1)` or `(D)`. A bare number such as `(2)` is
  // often a count and stays.
  if (RegExp(r'^[A-Za-z]{1,2}\d{0,2}$').hasMatch(text)) return true;
  final first = text.split(RegExp(r'[.,·]')).first.trim();
  return first != text && _parenthesizedTags.contains(first);
}
