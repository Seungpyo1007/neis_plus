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
