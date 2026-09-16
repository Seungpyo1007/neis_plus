<p align="center">
  <img src="https://raw.githubusercontent.com/Seungpyo1007/neis_plus/main/assets/neis_plus-logo.png" alt="NEIS+ logo: a graduation cap with a plus badge" width="128">
</p>

<h1 align="center">NEIS+</h1>

<p align="center">
  <a href="https://pub.dev/packages/neis_plus"><img src="https://img.shields.io/pub/v/neis_plus" alt="pub version"></a>
  <a href="https://pub.dev/packages/neis_plus/score"><img src="https://img.shields.io/pub/points/neis_plus" alt="pub points"></a>
  <a href="https://github.com/Seungpyo1007/neis_plus/actions/workflows/ci.yml"><img src="https://github.com/Seungpyo1007/neis_plus/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/Seungpyo1007/neis_plus/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT license"></a>
</p>

Read Korean school data from the NEIS open API: every service it publishes,
from school search and meals to timetables, academies, and departments.

This is an unofficial package. It is not affiliated with, or endorsed by, NEIS
or any office of education.

```dart
final neis = NeisClient();

final school = (await neis.schools(name: '서울고등학교')).first;
final meals = await neis.meals(school, date: DateTime.now());

for (final dish in meals.first.dishes) {
  print('${dish.name} ${dish.allergenNames}'); // 미역국 [난류, 대두, 밀]
}

neis.close();
```

## Works without an API key

NEIS answers without a key, so you can try the package immediately. A keyless
call returns **5 rows** — NEIS ignores both `pSize` and the page number — so
register a key at [open.neis.go.kr](https://open.neis.go.kr) for real use:

```dart
final neis = NeisClient(apiKey: 'YOUR-KEY');
```

## Every NEIS service

NEIS publishes 16 services and this package covers all of them. Each has a
method, and [`NeisService`](lib/src/services.dart) names them all for
[`call`](#any-service-by-name).

| Service | 이름 | Method |
| --- | --- | --- |
| `schoolInfo` | 학교기본정보 | `schools()` |
| `mealServiceDietInfo` | 급식식단정보 | `meals()` |
| `SchoolSchedule` | 학사일정 | `schedule()` |
| `classInfo` | 학급정보 | `classes()` |
| `elsTimetable` `misTimetable` `hisTimetable` `spsTimetable` | 초·중·고·특수 시간표 | `timetable()` |
| `elsTimetablebgs` `misTimetablebgs` `hisTimetablebgs` `spsTimetablebgs` | 과거연도 시간표 | `timetable(archived: true)` |
| `acaInsTiInfo` | 학원교습소정보 | `academies()` |
| `schoolMajorinfo` | 학교학과정보 | `majors()` |
| `schulAflcoinfo` | 학교계열정보 | `tracks()` |
| `tiClrminfo` | 시간표강의실정보 | `classrooms()` |

## Features

- **Schools**: search by name, region, or office of education, with the level
  (초·중·고·특수) parsed.
- **Meals**: dishes split out of the raw `<br/>` menu, with allergen numbers
  turned into Korean names, plus calories, servings, and origin.
- **Timetables**: the right service is chosen for the school level, past
  school years included, and lessons come back sorted by date and period.
- **Calendar**: events with `isSchoolClosed` for 휴업일.
- **Classes, departments, tracks, classrooms**: the structure behind a
  timetable.
- **Academies**: 학원 and 교습소 by region, field, and course.
- **Any service by name**: `call(NeisService.…)` with required parameters
  checked before the request leaves.
- **Office codes**: `NeisOffice` holds all 18 `ATPT_OFCDC_SC_CODE` values.
- **No data is not an error**: `INFO-200` returns an empty list.

## Platform support

Pure Dart on top of `package:http`: Dart VM, Flutter on Android, iOS, Windows,
macOS, Linux, and the web.

## Installation

```yaml
dependencies:
  neis_plus: ^0.0.3
```

## Usage

A week of meals, then this week's timetable for one class:

```dart
final neis = NeisClient(apiKey: key);
final school = (await neis.schools(name: '서울고등학교')).first;

final meals = await neis.meals(
  school,
  from: DateTime(2026, 6, 1),
  to: DateTime(2026, 6, 5),
);

final lessons = await neis.timetable(
  school,
  from: DateTime(2026, 6, 1),
  to: DateTime(2026, 6, 5),
  grade: '1',
  className: '3',
);
```

A past school year lives in a separate NEIS service, so ask for it:

```dart
final old = await neis.timetable(school, year: '2023', archived: true);
```

School calendar, skipping closed days:

```dart
final events = await neis.schedule(
  school,
  from: DateTime(2026, 3, 1),
  to: DateTime(2026, 3, 31),
);

for (final event in events.where((e) => !e.isSchoolClosed)) {
  print('${event.date}: ${event.name}');
}
```

Academies in a district:

```dart
final academies = await neis.academies(
  officeCode: NeisOffice.seoul.code,
  district: '강남구',
  realm: '입시.검정 및 보습',
);

for (final academy in academies) {
  print('${academy.name} ${academy.level} ${academy.phone}');
}
```

Departments and tracks of a vocational school, and the classrooms its
timetable uses:

```dart
final majors = await neis.majors(school: school);
final tracks = await neis.tracks(school: school);
final rooms = await neis.classrooms(school, year: '2026');
```

### Any service by name

```dart
final rows = await neis.call(NeisService.acaInsTiInfo, {
  'ATPT_OFCDC_SC_CODE': NeisOffice.seoul.code,
  'ACA_NM': '수학',
});

for (final row in rows) {
  print('${row.text('ACA_NM')} ${row.date('ESTBL_YMD')}');
}
```

`call` checks `NeisService.requiredParams` first, so a forgotten parameter
throws `missing_parameter` naming it instead of NEIS's unhelpful `ERROR-300`.
`rawRows` still takes a plain service name for anything NEIS adds later.

## Errors

```dart
try {
  await neis.meals(school, date: DateTime.now());
} on NeisException catch (error) {
  switch (error.code) {
    case 'invalid_key':
      print('키가 잘못되었거나 아직 활성화되지 않았습니다');
    case 'rate_limit':
      print('요청 횟수를 초과했습니다');
    default:
      print('${error.code}: $error (${error.resultCode})');
  }
}
```

| Code | Meaning |
| --- | --- |
| `invalid_key` | `ERROR-290`, key unknown or not active |
| `key_disabled` | `INFO-300`, key blocked by an administrator |
| `missing_parameter` | `ERROR-300`, a required parameter is missing |
| `invalid_parameter` | `ERROR-333` and friends, a parameter is malformed |
| `unknown_service` | `ERROR-310`, no such NEIS service |
| `too_many_rows` | `ERROR-336`, more than 1000 rows requested |
| `rate_limit` | `ERROR-337`, request limit exceeded |
| `server_error` | `ERROR-500`, `ERROR-600`, `ERROR-601` |
| `http_error`, `timeout`, `invalid_response` | The request never produced usable JSON |

## Limitations

- Without an API key NEIS sends 5 rows and ignores the page number, so a
  keyless call cannot read more than that.
- NEIS ignores `AY` on `SchoolSchedule`, so `schedule(year:)` never filtered
  anything and is deprecated; pass `from` and `to` instead.
- The past-year timetable services are not in the NEIS catalogue, so their
  parameters can change without notice. They also write class names
  differently — `CLASS_NM` is `01` there where the current service says `1`.
- Rows keep NEIS field names in `raw`, and the typed classes cover the common
  fields only.
- NEIS publishes data per office of education; a school that has not uploaded
  its meals or timetable returns an empty list, not an error.
- Timetable services differ by school level. A school built with
  `NeisSchool.codes` has no level, so pass `kind:` to `timetable`.
- Office names change — 광주 and 전남 now both answer as
  전남광주통합특별시교육청 — so `NeisOffice.label` is a hint and
  `ATPT_OFCDC_SC_NM` on a row is the current name.
- Allergen numbers follow the 19 items NEIS lists; schools sometimes write
  menus that do not follow the format, and those dishes come back without
  allergens.
