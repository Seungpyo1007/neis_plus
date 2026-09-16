/// One service of the NEIS open API.
///
/// Every service NEIS publishes is a constant on this class, so a call can
/// name one instead of spelling its path. That matters because the paths are
/// case sensitive and not consistent: `SchoolSchedule` starts with a capital
/// S, while `schoolMajorinfo`, `schulAflcoinfo`, and `tiClrminfo` end in a
/// lowercase `info`.
///
/// ```dart
/// final rows = await neis.call(NeisService.acaInsTiInfo, {
///   'ATPT_OFCDC_SC_CODE': 'B10',
///   'ACA_NM': '수학',
/// });
/// ```
class NeisService {
  const NeisService._(
    this.path,
    this.koreanName, {
    String? envelopeKey,
    this.requiredParams = const <String>[],
    this.optionalParams = const <String>[],
  }) : _envelopeKey = envelopeKey;

  /// Path segment under `https://open.neis.go.kr/hub/`.
  final String path;

  /// Name NEIS gives the service in its own catalogue.
  final String koreanName;

  final String? _envelopeKey;

  /// Key the service uses for its rows in the JSON response.
  ///
  /// It is [path] for every service except the past-year timetables, which
  /// answer under the name of the current-year service.
  String get envelopeKey => _envelopeKey ?? path;

  /// Parameters NEIS rejects the request without.
  final List<String> requiredParams;

  /// Parameters NEIS accepts as filters. Anything else is ignored silently.
  final List<String> optionalParams;

  @override
  String toString() => '$path ($koreanName)';

  static const _office = 'ATPT_OFCDC_SC_CODE';
  static const _school = 'SD_SCHUL_CODE';
  static const _schoolOnly = <String>[_office, _school];

  /// 학교기본정보. The only service that answers without any parameter.
  static const schoolInfo = NeisService._(
    'schoolInfo',
    '학교기본정보',
    optionalParams: [
      _office,
      _school,
      'SCHUL_NM',
      'SCHUL_KND_SC_NM',
      'LCTN_SC_NM',
      'FOND_SC_NM',
    ],
  );

  /// 급식식단정보.
  static const mealServiceDietInfo = NeisService._(
    'mealServiceDietInfo',
    '급식식단정보',
    requiredParams: _schoolOnly,
    optionalParams: [
      'MMEAL_SC_CODE',
      'MLSV_YMD',
      'MLSV_FROM_YMD',
      'MLSV_TO_YMD',
    ],
  );

  /// 학사일정. NEIS ignores `AY` here, so filter by date instead.
  static const schoolSchedule = NeisService._(
    'SchoolSchedule',
    '학사일정',
    requiredParams: _schoolOnly,
    optionalParams: [
      'DGHT_CRSE_SC_NM',
      'SCHUL_CRSE_SC_NM',
      'AA_YMD',
      'AA_FROM_YMD',
      'AA_TO_YMD',
    ],
  );

  /// 학급정보.
  static const classInfo = NeisService._(
    'classInfo',
    '학급정보',
    requiredParams: _schoolOnly,
    optionalParams: [
      'AY',
      'GRADE',
      'DGHT_CRSE_SC_NM',
      'SCHUL_CRSE_SC_NM',
      'ORD_SC_NM',
      'DDDEP_NM',
    ],
  );

  /// 학원교습소정보. Covers 학원 and 교습소, not schools.
  static const acaInsTiInfo = NeisService._(
    'acaInsTiInfo',
    '학원교습소정보',
    requiredParams: [_office],
    optionalParams: [
      'ADMST_ZONE_NM',
      'ACA_ASNUM',
      'ACA_NM',
      'REALM_SC_NM',
      'LE_ORD_NM',
      'LE_CRSE_NM',
    ],
  );

  /// 학교학과정보.
  static const schoolMajorInfo = NeisService._(
    'schoolMajorinfo',
    '학교학과정보',
    requiredParams: [_office],
    optionalParams: [_school, 'DGHT_CRSE_SC_NM', 'ORD_SC_NM'],
  );

  /// 학교계열정보.
  static const schulAflcoInfo = NeisService._(
    'schulAflcoinfo',
    '학교계열정보',
    requiredParams: [_office],
    optionalParams: [_school, 'DGHT_CRSE_SC_NM'],
  );

  /// 시간표강의실정보.
  static const tiClrmInfo = NeisService._(
    'tiClrminfo',
    '시간표강의실정보',
    requiredParams: _schoolOnly,
    optionalParams: [
      'AY',
      'GRADE',
      'SEM',
      'SCHUL_CRSE_SC_NM',
      'DGHT_CRSE_SC_NM',
      'ORD_SC_NM',
      'DDDEP_NM',
    ],
  );

  static const _elsParams = <String>[
    'AY',
    'SEM',
    'ALL_TI_YMD',
    'GRADE',
    'CLASS_NM',
    'PERIO',
    'TI_FROM_YMD',
    'TI_TO_YMD',
  ];
  static const _misParams = <String>[
    'AY',
    'SEM',
    'ALL_TI_YMD',
    'DGHT_CRSE_SC_NM',
    'GRADE',
    'CLASS_NM',
    'PERIO',
    'TI_FROM_YMD',
    'TI_TO_YMD',
  ];
  static const _hisParams = <String>[
    'AY',
    'SEM',
    'ALL_TI_YMD',
    'DGHT_CRSE_SC_NM',
    'ORD_SC_NM',
    'DDDEP_NM',
    'GRADE',
    'CLRM_NM',
    'CLASS_NM',
    'TI_FROM_YMD',
    'TI_TO_YMD',
  ];
  static const _spsParams = <String>[
    'AY',
    'SEM',
    'ALL_TI_YMD',
    'SCHUL_CRSE_SC_NM',
    'GRADE',
    'CLRM_NM',
    'CLASS_NM',
    'PERIO',
    'TI_FROM_YMD',
    'TI_TO_YMD',
  ];

  /// 초등학교시간표.
  static const elsTimetable = NeisService._(
    'elsTimetable',
    '초등학교시간표',
    requiredParams: _schoolOnly,
    optionalParams: _elsParams,
  );

  /// 중학교시간표.
  static const misTimetable = NeisService._(
    'misTimetable',
    '중학교시간표',
    requiredParams: _schoolOnly,
    optionalParams: _misParams,
  );

  /// 고등학교시간표.
  static const hisTimetable = NeisService._(
    'hisTimetable',
    '고등학교시간표',
    requiredParams: _schoolOnly,
    optionalParams: _hisParams,
  );

  /// 특수학교시간표.
  static const spsTimetable = NeisService._(
    'spsTimetable',
    '특수학교시간표',
    requiredParams: _schoolOnly,
    optionalParams: _spsParams,
  );

  /// 초등학교시간표(과거연도).
  static const elsTimetableArchive = NeisService._(
    'elsTimetablebgs',
    '초등학교시간표(과거연도)',
    envelopeKey: 'elsTimetable',
    requiredParams: _schoolOnly,
    optionalParams: _elsParams,
  );

  /// 중학교시간표(과거연도).
  static const misTimetableArchive = NeisService._(
    'misTimetablebgs',
    '중학교시간표(과거연도)',
    envelopeKey: 'misTimetable',
    requiredParams: _schoolOnly,
    optionalParams: _misParams,
  );

  /// 고등학교시간표(과거연도).
  static const hisTimetableArchive = NeisService._(
    'hisTimetablebgs',
    '고등학교시간표(과거연도)',
    envelopeKey: 'hisTimetable',
    requiredParams: _schoolOnly,
    optionalParams: _hisParams,
  );

  /// 특수학교시간표(과거연도).
  static const spsTimetableArchive = NeisService._(
    'spsTimetablebgs',
    '특수학교시간표(과거연도)',
    envelopeKey: 'spsTimetable',
    requiredParams: _schoolOnly,
    optionalParams: _spsParams,
  );

  /// Every service this package knows about.
  static const all = <NeisService>[
    schoolInfo,
    mealServiceDietInfo,
    schoolSchedule,
    classInfo,
    acaInsTiInfo,
    schoolMajorInfo,
    schulAflcoInfo,
    tiClrmInfo,
    elsTimetable,
    misTimetable,
    hisTimetable,
    spsTimetable,
    elsTimetableArchive,
    misTimetableArchive,
    hisTimetableArchive,
    spsTimetableArchive,
  ];

  /// Looks a service up by its [path], or returns `null` for an unknown one.
  static NeisService? byPath(String path) {
    for (final service in all) {
      if (service.path == path) return service;
    }
    return null;
  }
}

/// An office of education, the `ATPT_OFCDC_SC_CODE` every service is keyed by.
///
/// Only the code is stable. NEIS renames offices — 광주 and 전남 now both
/// answer as 전남광주통합특별시교육청 — so read the current name from a row's
/// `ATPT_OFCDC_SC_NM` rather than from [label].
class NeisOffice {
  const NeisOffice._(this.code, this.label);

  /// `ATPT_OFCDC_SC_CODE`, such as `B10`.
  final String code;

  /// Short region label, for menus. Not the official name.
  final String label;

  @override
  String toString() => '$code ($label)';

  /// 서울.
  static const seoul = NeisOffice._('B10', '서울');

  /// 부산.
  static const busan = NeisOffice._('C10', '부산');

  /// 대구.
  static const daegu = NeisOffice._('D10', '대구');

  /// 인천.
  static const incheon = NeisOffice._('E10', '인천');

  /// 광주.
  static const gwangju = NeisOffice._('F10', '광주');

  /// 대전.
  static const daejeon = NeisOffice._('G10', '대전');

  /// 울산.
  static const ulsan = NeisOffice._('H10', '울산');

  /// 세종.
  static const sejong = NeisOffice._('I10', '세종');

  /// 경기.
  static const gyeonggi = NeisOffice._('J10', '경기');

  /// 강원.
  static const gangwon = NeisOffice._('K10', '강원');

  /// 충북.
  static const chungbuk = NeisOffice._('M10', '충북');

  /// 충남.
  static const chungnam = NeisOffice._('N10', '충남');

  /// 전북.
  static const jeonbuk = NeisOffice._('P10', '전북');

  /// 전남.
  static const jeonnam = NeisOffice._('Q10', '전남');

  /// 경북.
  static const gyeongbuk = NeisOffice._('R10', '경북');

  /// 경남.
  static const gyeongnam = NeisOffice._('S10', '경남');

  /// 제주.
  static const jeju = NeisOffice._('T10', '제주');

  /// 재외한국학교.
  static const overseas = NeisOffice._('V10', '재외한국학교');

  /// Every office code NEIS answers for.
  static const all = <NeisOffice>[
    seoul,
    busan,
    daegu,
    incheon,
    gwangju,
    daejeon,
    ulsan,
    sejong,
    gyeonggi,
    gangwon,
    chungbuk,
    chungnam,
    jeonbuk,
    jeonnam,
    gyeongbuk,
    gyeongnam,
    jeju,
    overseas,
  ];

  /// Looks an office up by its [code], or returns `null`.
  static NeisOffice? byCode(String code) {
    for (final office in all) {
      if (office.code == code) return office;
    }
    return null;
  }
}
