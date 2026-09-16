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
