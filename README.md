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

Read Korean school data from the NEIS open API: find a school, then read its
meals, timetable, calendar, and classes.

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

NEIS answers a limited number of requests without a key, so you can try the
package immediately. Register a key at
[open.neis.go.kr](https://open.neis.go.kr) and pass it for regular use:

```dart
final neis = NeisClient(apiKey: 'YOUR-KEY');
```

## Features

- **Schools**: search by name, region, or office of education, with the level
  (초·중·고·특수) parsed.
- **Meals**: dishes split out of the raw `<br/>` menu, with allergen numbers
  turned into Korean names, plus calories, servings, and origin.
- **Timetables**: the right service is chosen for the school level, and
  lessons come back sorted by date and period.
- **Calendar**: events with `isSchoolClosed` for 휴업일.
- **Classes**: grade, class name, course, and department.
- **Anything else**: `rawRows` calls any NEIS service and returns its rows.
- **Paging**: follows `list_total_count` across pages.
- **No data is not an error**: `INFO-200` returns an empty list.

## Platform support

Pure Dart on top of `package:http`: Dart VM, Flutter on Android, iOS, Windows,
macOS, Linux, and the web.

## Installation

```yaml
dependencies:
  neis_plus: ^0.0.1
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

Call a service this package does not wrap:

```dart
final rows = await neis.rawRows('acaInsTiInfo', {
  'ATPT_OFCDC_SC_CODE': 'B10',
  'ACA_NM': '수학',
});
```

Handle failures by code:

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

- Rows keep NEIS field names in `raw`, and the typed classes cover the common
  fields only.
- NEIS publishes data per office of education; a school that has not uploaded
  its meals or timetable returns an empty list, not an error.
- Timetable services differ by school level. A school built with
  `NeisSchool.codes` has no level, so pass `kind:` to `timetable`.
- Allergen numbers follow the 19 items NEIS lists; schools sometimes write
  menus that do not follow the format, and those dishes come back without
  allergens.
