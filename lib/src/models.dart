import 'services.dart';

/// School level, from `SCHUL_KND_SC_NM`. It decides which timetable service a
/// school uses.
enum NeisSchoolKind {
  /// 초등학교.
  elementary('초등학교', NeisService.elsTimetable, NeisService.elsTimetableArchive),

  /// 중학교.
  middle('중학교', NeisService.misTimetable, NeisService.misTimetableArchive),

  /// 고등학교.
  high('고등학교', NeisService.hisTimetable, NeisService.hisTimetableArchive),

  /// 특수학교.
  special('특수학교', NeisService.spsTimetable, NeisService.spsTimetableArchive),

  /// Anything else, such as 각종학교.
  other('', NeisService.hisTimetable, NeisService.hisTimetableArchive);

  const NeisSchoolKind(this.label, this.timetable, this.archiveTimetable);

  /// Korean label used by NEIS.
  final String label;

  /// Service that serves this level's timetable for the current school years.
  final NeisService timetable;

  /// Service that serves this level's timetable for past school years.
  ///
  /// NEIS splits the two: a year is served by one or the other, never both.
  final NeisService archiveTimetable;

  /// Path of [timetable].
  String get timetableService => timetable.path;

  /// Reads `SCHUL_KND_SC_NM`.
  static NeisSchoolKind fromLabel(String? label) {
    final text = label ?? '';
    for (final kind in values) {
      if (kind != other && text.contains(kind.label)) return kind;
    }
    return other;
  }
}

/// A school registered with NEIS.
class NeisSchool {
  /// Creates a school.
  const NeisSchool({
    required this.officeCode,
    required this.schoolCode,
    this.officeName = '',
    this.name = '',
    this.englishName,
    this.kind = NeisSchoolKind.other,
    this.region,
    this.foundation,
    this.address,
    this.phone,
    this.website,
    this.raw = const <String, Object?>{},
  });

  /// Creates a reference from codes you already have, for when you skip the
  /// school search.
  const NeisSchool.codes(
    this.officeCode,
    this.schoolCode, {
    this.kind = NeisSchoolKind.other,
  }) : officeName = '',
       name = '',
       englishName = null,
       region = null,
       foundation = null,
       address = null,
       phone = null,
       website = null,
       raw = const <String, Object?>{};

  /// Reads a `schoolInfo` row.
  factory NeisSchool.fromRow(Map<String, Object?> row) => NeisSchool(
    officeCode: '${row['ATPT_OFCDC_SC_CODE'] ?? ''}',
    schoolCode: '${row['SD_SCHUL_CODE'] ?? ''}',
    officeName: '${row['ATPT_OFCDC_SC_NM'] ?? ''}',
    name: '${row['SCHUL_NM'] ?? ''}',
    englishName: _text(row['ENG_SCHUL_NM']),
    kind: NeisSchoolKind.fromLabel(_text(row['SCHUL_KND_SC_NM'])),
    region: _text(row['LCTN_SC_NM']),
    foundation: _text(row['FOND_SC_NM']),
    address: _text(row['ORG_RDNMA']),
    phone: _text(row['ORG_TELNO']),
    website: _text(row['HMPG_ADRES']),
    raw: row,
  );

  /// Office of education code, `ATPT_OFCDC_SC_CODE`, such as `B10` for Seoul.
  final String officeCode;

  /// School code, `SD_SCHUL_CODE`.
  final String schoolCode;

  /// Office of education name.
  final String officeName;

  /// School name.
  final String name;

  /// School name in English, when published.
  final String? englishName;

  /// School level.
  final NeisSchoolKind kind;

  /// Province or metropolitan city.
  final String? region;

  /// 공립 or 사립.
  final String? foundation;

  /// Road name address.
  final String? address;

  /// Phone number.
  final String? phone;

  /// Website, when published.
  final String? website;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisSchool($name, $officeCode/$schoolCode)';
}

/// One dish of a school meal, with the allergens NEIS marks on it.
class NeisDish {
  /// Creates a dish.
  const NeisDish(this.name, {this.allergens = const <int>[]});

  /// Dish name without the allergen numbers.
  final String name;

  /// Allergen numbers, 1 to 19, as published by NEIS.
  final List<int> allergens;

  /// Korean allergen names for [allergens].
  List<String> get allergenNames => [
    for (final number in allergens)
      if (number >= 1 && number <= neisAllergens.length)
        neisAllergens[number - 1],
  ];

  @override
  String toString() => allergens.isEmpty ? name : '$name ($allergens)';
}

/// The 19 allergens NEIS numbers in meal listings, in order.
const neisAllergens = <String>[
  '난류',
  '우유',
  '메밀',
  '땅콩',
  '대두',
  '밀',
  '고등어',
  '게',
  '새우',
  '돼지고기',
  '복숭아',
  '토마토',
  '아황산류',
  '호두',
  '닭고기',
  '쇠고기',
  '오징어',
  '조개류',
  '잣',
];

/// A school meal served on one day.
class NeisMeal {
  /// Creates a meal.
  const NeisMeal({
    required this.date,
    required this.typeName,
    this.dishes = const <NeisDish>[],
    this.calories,
    this.nutrients,
    this.servings,
    this.origin,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `mealServiceDietInfo` row.
  factory NeisMeal.fromRow(Map<String, Object?> row) => NeisMeal(
    date: parseNeisDate('${row['MLSV_YMD'] ?? ''}') ?? DateTime(0),
    typeName: '${row['MMEAL_SC_NM'] ?? ''}',
    dishes: parseNeisDishes('${row['DDISH_NM'] ?? ''}'),
    calories: _text(row['CAL_INFO']),
    nutrients: _text(row['NTR_INFO']),
    servings: int.tryParse('${row['MLSV_FGR'] ?? ''}'.trim()),
    origin: _text(row['ORPLC_INFO']),
    raw: row,
  );

  /// Day the meal is served.
  final DateTime date;

  /// 조식, 중식, or 석식.
  final String typeName;

  /// Dishes on the menu.
  final List<NeisDish> dishes;

  /// Calories as published, such as `533.5 Kcal`.
  final String? calories;

  /// Nutrient breakdown as published.
  final String? nutrients;

  /// Number of people served.
  final int? servings;

  /// Origin of ingredients as published.
  final String? origin;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() =>
      'NeisMeal(${date.year}-${date.month}-${date.day} $typeName, '
      '${dishes.length} dishes)';
}

/// One entry of a school calendar.
class NeisScheduleEvent {
  /// Creates an event.
  const NeisScheduleEvent({
    required this.date,
    required this.name,
    this.content,
    this.dayKind,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `SchoolSchedule` row.
  factory NeisScheduleEvent.fromRow(Map<String, Object?> row) =>
      NeisScheduleEvent(
        date: parseNeisDate('${row['AA_YMD'] ?? ''}') ?? DateTime(0),
        name: '${row['EVENT_NM'] ?? ''}',
        content: _text(row['EVENT_CNTNT']),
        dayKind: _text(row['SBTR_DD_SC_NM']),
        raw: row,
      );

  /// Day of the event.
  final DateTime date;

  /// Event name, such as 개학식.
  final String name;

  /// Longer description, when published.
  final String? content;

  /// `휴업일` when school is closed that day.
  final String? dayKind;

  /// Whether school is closed on this day.
  bool get isSchoolClosed => dayKind == '휴업일';

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() =>
      'NeisScheduleEvent(${date.year}-${date.month}-${date.day}, $name)';
}

/// One period of a class timetable.
class NeisLesson {
  /// Creates a lesson.
  const NeisLesson({
    required this.date,
    required this.period,
    required this.subject,
    this.grade,
    this.className,
    this.raw = const <String, Object?>{},
  });

  /// Reads a timetable row.
  factory NeisLesson.fromRow(Map<String, Object?> row) => NeisLesson(
    date: parseNeisDate('${row['ALL_TI_YMD'] ?? ''}') ?? DateTime(0),
    period: int.tryParse('${row['PERIO'] ?? ''}'.trim()) ?? 0,
    subject: '${row['ITRT_CNTNT'] ?? ''}',
    grade: _text(row['GRADE']),
    className: _text(row['CLASS_NM']),
    raw: row,
  );

  /// Day of the lesson.
  final DateTime date;

  /// Period number, starting at 1.
  final int period;

  /// Subject taught, from `ITRT_CNTNT`.
  final String subject;

  /// Grade, when published.
  final String? grade;

  /// Class name, when published.
  final String? className;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisLesson($period교시 $subject)';
}

/// One class of a school, from `classInfo`.
class NeisClass {
  /// Creates a class.
  const NeisClass({
    required this.year,
    required this.grade,
    required this.name,
    this.courseName,
    this.departmentName,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `classInfo` row.
  factory NeisClass.fromRow(Map<String, Object?> row) => NeisClass(
    year: '${row['AY'] ?? ''}',
    grade: '${row['GRADE'] ?? ''}',
    name: '${row['CLASS_NM'] ?? ''}',
    courseName: _text(row['SCHUL_CRSE_SC_NM']),
    departmentName: _text(row['DDDEP_NM']),
    raw: row,
  );

  /// School year, such as `2026`.
  final String year;

  /// Grade, such as `1`.
  final String grade;

  /// Class name, such as `1`.
  final String name;

  /// Course name, such as 고등학교.
  final String? courseName;

  /// Department name for vocational schools.
  final String? departmentName;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisClass($year $grade-$name)';
}

/// A 학원 or 교습소, from `acaInsTiInfo`.
class NeisAcademy {
  /// Creates an academy.
  const NeisAcademy({
    required this.name,
    required this.registrationNumber,
    this.officeCode = '',
    this.officeName = '',
    this.kindName,
    this.district,
    this.realm,
    this.level,
    this.courseName,
    this.courseList,
    this.capacity,
    this.tuition,
    this.address,
    this.phone,
    this.status,
    this.establishedOn,
    this.raw = const <String, Object?>{},
  });

  /// Reads an `acaInsTiInfo` row.
  factory NeisAcademy.fromRow(Map<String, Object?> row) => NeisAcademy(
    name: '${row['ACA_NM'] ?? ''}',
    registrationNumber: '${row['ACA_ASNUM'] ?? ''}',
    officeCode: '${row['ATPT_OFCDC_SC_CODE'] ?? ''}',
    officeName: '${row['ATPT_OFCDC_SC_NM'] ?? ''}',
    kindName: _text(row['ACA_INSTI_SC_NM']),
    district: _text(row['ADMST_ZONE_NM']),
    realm: _text(row['REALM_SC_NM']),
    level: _text(row['LE_ORD_NM']),
    courseName: _text(row['LE_CRSE_NM']),
    courseList: _text(row['LE_CRSE_LIST_NM']),
    capacity: int.tryParse('${row['TOFOR_SMTOT'] ?? ''}'.trim()),
    tuition: _text(row['PSNBY_THCC_CNTNT']),
    address: _text(row['FA_RDNMA']),
    phone: _text(row['FA_TELNO']),
    status: _text(row['REG_STTUS_NM']),
    establishedOn: parseNeisDate('${row['ESTBL_YMD'] ?? ''}'),
    raw: row,
  );

  /// Name of the academy.
  final String name;

  /// Registration number, `ACA_ASNUM`.
  final String registrationNumber;

  /// Office of education code.
  final String officeCode;

  /// Office of education name.
  final String officeName;

  /// 학원 or 교습소.
  final String? kindName;

  /// 행정구역, such as 강남구.
  final String? district;

  /// Field of study, such as 입시·검정 및 보습.
  final String? realm;

  /// Level taught, such as 고등학생.
  final String? level;

  /// Course name.
  final String? courseName;

  /// Every course the academy registered.
  final String? courseList;

  /// Registered student capacity.
  final int? capacity;

  /// Tuition as published.
  final String? tuition;

  /// Road name address.
  final String? address;

  /// Phone number.
  final String? phone;

  /// Registration status, such as 정상.
  final String? status;

  /// Day the academy was established.
  final DateTime? establishedOn;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisAcademy($name, $realm)';
}

/// A department of a school, from `schoolMajorinfo`.
class NeisMajor {
  /// Creates a department.
  const NeisMajor({
    required this.name,
    this.officeCode = '',
    this.schoolCode = '',
    this.schoolName = '',
    this.trackName,
    this.dayNightName,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `schoolMajorinfo` row.
  factory NeisMajor.fromRow(Map<String, Object?> row) => NeisMajor(
    name: '${row['DDDEP_NM'] ?? ''}',
    officeCode: '${row['ATPT_OFCDC_SC_CODE'] ?? ''}',
    schoolCode: '${row['SD_SCHUL_CODE'] ?? ''}',
    schoolName: '${row['SCHUL_NM'] ?? ''}',
    trackName: _text(row['ORD_SC_NM']),
    dayNightName: _text(row['DGHT_CRSE_SC_NM']),
    raw: row,
  );

  /// Department name, such as 소프트웨어과.
  final String name;

  /// Office of education code.
  final String officeCode;

  /// School code.
  final String schoolCode;

  /// School name.
  final String schoolName;

  /// Track the department belongs to, such as 공업계.
  final String? trackName;

  /// 주간 or 야간.
  final String? dayNightName;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisMajor($schoolName $name)';
}

/// A track of a school, from `schulAflcoinfo`.
class NeisTrack {
  /// Creates a track.
  const NeisTrack({
    required this.name,
    this.officeCode = '',
    this.schoolCode = '',
    this.schoolName = '',
    this.dayNightName,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `schulAflcoinfo` row.
  factory NeisTrack.fromRow(Map<String, Object?> row) => NeisTrack(
    name: '${row['ORD_SC_NM'] ?? ''}',
    officeCode: '${row['ATPT_OFCDC_SC_CODE'] ?? ''}',
    schoolCode: '${row['SD_SCHUL_CODE'] ?? ''}',
    schoolName: '${row['SCHUL_NM'] ?? ''}',
    dayNightName: _text(row['DGHT_CRSE_SC_NM']),
    raw: row,
  );

  /// Track name, such as 일반계.
  final String name;

  /// Office of education code.
  final String officeCode;

  /// School code.
  final String schoolCode;

  /// School name.
  final String schoolName;

  /// 주간 or 야간.
  final String? dayNightName;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisTrack($schoolName $name)';
}

/// A classroom a timetable can be taught in, from `tiClrminfo`.
class NeisClassroom {
  /// Creates a classroom.
  const NeisClassroom({
    required this.name,
    this.year = '',
    this.semester,
    this.grade,
    this.courseName,
    this.trackName,
    this.departmentName,
    this.dayNightName,
    this.raw = const <String, Object?>{},
  });

  /// Reads a `tiClrminfo` row.
  factory NeisClassroom.fromRow(Map<String, Object?> row) => NeisClassroom(
    name: '${row['CLRM_NM'] ?? ''}',
    year: '${row['AY'] ?? ''}',
    semester: _text(row['SEM']),
    grade: _text(row['GRADE']),
    courseName: _text(row['SCHUL_CRSE_SC_NM']),
    trackName: _text(row['ORD_SC_NM']),
    departmentName: _text(row['DDDEP_NM']),
    dayNightName: _text(row['DGHT_CRSE_SC_NM']),
    raw: row,
  );

  /// Classroom name.
  final String name;

  /// School year, such as `2026`.
  final String year;

  /// Semester, `1` or `2`.
  final String? semester;

  /// Grade using the classroom.
  final String? grade;

  /// Course name, such as 고등학교.
  final String? courseName;

  /// Track name, such as 일반계.
  final String? trackName;

  /// Department name for vocational schools.
  final String? departmentName;

  /// 주간 or 야간.
  final String? dayNightName;

  /// The full row, for fields this class does not model.
  final Map<String, Object?> raw;

  @override
  String toString() => 'NeisClassroom($year $name)';
}

/// Parses a NEIS `yyyyMMdd` date, or returns `null`.
DateTime? parseNeisDate(String value) {
  final text = value.trim();
  if (text.length != 8) return null;
  final year = int.tryParse(text.substring(0, 4));
  final month = int.tryParse(text.substring(4, 6));
  final day = int.tryParse(text.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Formats a date the way NEIS parameters expect.
String formatNeisDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

/// Splits a `DDISH_NM` menu into dishes and their allergen numbers.
///
/// NEIS separates dishes with `<br/>` and appends allergen numbers in
/// parentheses, as in `미역국 (1.5.6)`.
List<NeisDish> parseNeisDishes(String menu) {
  final dishes = <NeisDish>[];
  for (final part in menu.split(RegExp(r'<br\s*/?>', caseSensitive: false))) {
    final text = part.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) continue;
    final match = RegExp(r'\(([\d.\s]+)\)\s*$').firstMatch(text);
    if (match == null) {
      dishes.add(NeisDish(text));
      continue;
    }
    final numbers = [
      for (final piece in match[1]!.split(RegExp(r'[.\s]+')))
        ?int.tryParse(piece.trim()),
    ];
    dishes.add(
      NeisDish(text.substring(0, match.start).trim(), allergens: numbers),
    );
  }
  return dishes;
}

String? _text(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}
