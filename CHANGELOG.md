## 0.0.4

* Fix `NeisMeal.servings` always being `null` on the Dart VM and Flutter
  apps. NEIS sends `MLSV_FGR` as a JSON number such as `780.00`, which the VM
  decodes as a double. `NeisRow.integer` and `NeisRow.number` read numbers in
  either shape too.
* Fix meals and other data of an unrelated institution coming back for a
  planned school. `schools` leaves out schools whose code NEIS sends blank,
  codes are trimmed, and the school methods throw `missing_parameter` for a
  school without codes instead of sending them. `NeisSchool.hasCodes` tells.
* Fix past school years coming back empty from `timetable`. Without
  `archived`, it asks the service that usually holds the year first and the
  other when the answer is empty; `archived: true` or `false` still reads only
  one. When `className` matches nothing it tries the other spelling (`1` or
  `01`), since schools write it either way. NEIS has no 2024 timetable for
  many schools in either service, and those still come back empty.
* Fix `isSchoolClosed` missing public holidays: `공휴일` counts as closed, like
  `휴업일`.
* Fix lessons of several classes coming back interleaved. `timetable` sorts
  by date, grade, class, and period.
* Fix `timetable` silently reading the high school service for a school made
  with `NeisSchool.codes` and no `kind`. It throws `missing_parameter`.
* Fix `parseNeisDate` rolling impossible dates such as `20261340` into the
  next year. They are `null`.
* Add `neisToday()`, today's date in Korea whatever the device's time zone.
  The README and example use it instead of `DateTime.now()`.
* `pageSize` and `rawRows(rows:)` must be between 1 and 1000; other values
  throw a `RangeError` instead of failing at NEIS with `ERROR-336`.
* Retry a request that timed out once, like a dropped connection. A NEIS
  rate limit answer (`ERROR-337`) is not retried.
* `NeisMeal.nutrients` and `NeisMeal.origin` put each item on its own line
  instead of keeping NEIS's `<br/>` tags, and a bare `http://` website is
  `null`.
* README: warn against shipping an API key in an app, document the 500-row
  default limit, and link related packages.

## 0.0.3

* Cover every service the NEIS open API publishes. New methods: `academies`
  (학원교습소정보), `majors` (학교학과정보), `tracks` (학교계열정보), and
  `classrooms` (시간표강의실정보), with `NeisAcademy`, `NeisMajor`,
  `NeisTrack`, and `NeisClassroom`.
* `timetable(archived: true)` reads the past school years, which NEIS serves
  from separate `*bgs` services that answer under the current service's name.
* `NeisService` names all 16 services with their required and optional
  parameters, and `NeisOffice` holds the 18 `ATPT_OFCDC_SC_CODE` values.
* `call(NeisService, params)` reaches any service and returns `NeisRow`,
  rejecting a missing required parameter before the request is sent instead of
  leaving NEIS to answer `ERROR-300` without naming it.
* `schedule(year:)` is deprecated: NEIS ignores `AY` on `SchoolSchedule`, so
  it never filtered anything. Use `from` and `to`.
* Document that a keyless call returns 5 rows and cannot page, because NEIS
  ignores `pSize` and the page number without a key.

## 0.0.2

* Add the package logo and show it in the README. No code changes.

## 0.0.1

* Initial release.
* `NeisClient` reads schools, meals, timetables, school calendars, and classes
  from the NEIS open API, and `rawRows` calls any other NEIS service.
* An API key is optional: NEIS answers a limited number of requests without
  one.
* Meals are parsed into dishes with their allergen numbers and Korean allergen
  names.
* Timetables pick the service that matches the school level automatically
  (`elsTimetable`, `misTimetable`, `hisTimetable`, `spsTimetable`).
* Paging follows `list_total_count`, and `NeisException` reports
  `invalid_key`, `key_disabled`, `missing_parameter`, `invalid_parameter`,
  `unknown_service`, `too_many_rows`, `rate_limit`, `server_error`,
  `service_error`, `http_error`, `timeout`, and `invalid_response`.
