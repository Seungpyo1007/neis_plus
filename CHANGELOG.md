## 0.1.0

* Add `findSchools` and `findSchool`, which search by a name as people type it
  and sort the best match first. Short names work: `서울고` finds
  서울고등학교 and `경덕여고` finds 경덕여자고등학교, which NEIS's own search
  for the short name misses. `expandNeisSchoolName` and `rankNeisSchools` do
  the same without a request.
* Add `NeisMealType` (조식, 중식, 석식), `meals(type:)`, `NeisMeal.type`, and
  `todayMeals`, which reads today's meals in Korean time.
* Add `NeisDish.cleanName` and `NeisDish.markers`, which split the marks
  schools add to dish names (`*`, `@`, `(가)`, `(자율)`, `(점심)`, a trailing
  `s` or digit, `[기후동행식단]`) from the name. `NeisDish.name` is unchanged.
* Add `NeisMeal.kcal`, `NeisMeal.nutrition` (`NeisNutrient` with value and
  unit), and `NeisMeal.origins` (`NeisOrigin`), parsed from `CAL_INFO`,
  `NTR_INFO`, and `ORPLC_INFO`.
* Add `NeisAllergen`, an enum of the 19 allergens, with
  `NeisDish.allergenKinds` and `contains`, and `NeisMeal.allergens`,
  `containsAllergen`, `containsAnyAllergen`, and `dishesWithout`.
* Add `NeisPage`, with the total NEIS reports and whether the answer was cut
  off at `maxPages`, returned by the new `schoolsPage`, `academiesPage`,
  `rawPage`, and `callPage`. The list methods are unchanged.
* Add `stream`, which reads every page of a service lazily and stops
  requesting when the subscription is cancelled.
* Add `toIcs` on lists of `NeisScheduleEvent`, an iCalendar (RFC 5545) export
  with stable UIDs, a grade filter, and the weekly 토요휴업일 left out by
  default.
* Add the filters NEIS accepts but the methods did not: `kind` and
  `foundation` on `schools`; `courseName` and `dayNightName` on `schedule`;
  course, day or night, track, and department on `classes` and `classrooms`;
  `period`, `classroomName`, `courseName`, `dayNightName`, `trackName`, and
  `departmentName` on `timetable`.
* Add model fields NEIS sends: postal code, address detail, fax,
  coeducation, high school type, day or night, founding date, and supervising
  office on `NeisSchool`; school year, course, day or night, and `grades` with
  `appliesToGrade` and `isSaturdayBreak` on `NeisScheduleEvent`; school year,
  semester, classroom, course, day or night, track, and department on
  `NeisLesson`; day or night and track on `NeisClass`; registration date,
  suspension dates, simultaneous capacity, branch and tuition flags, address
  detail, and postal code on `NeisAcademy`; school name on `NeisMeal`.
* Add `NeisErrorCode`, constants for every `NeisException.code`.

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
