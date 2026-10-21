import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exception.dart';
import 'models.dart';
import 'row.dart';
import 'services.dart';
import 'values.dart';

/// Reads school data from the NEIS open API (`open.neis.go.kr`).
///
/// An API key is optional: NEIS answers a limited number of requests without
/// one, which is enough to try things out. Register a key for regular use.
///
/// ```dart
/// final neis = NeisClient();
/// final schools = await neis.schools(name: '서울고등학교');
/// final meals = await neis.meals(schools.first, date: neisToday());
/// neis.close();
/// ```
class NeisClient {
  /// Creates a client.
  ///
  /// [pageSize] must be between 1 and 1000, the most NEIS sends per request.
  NeisClient({
    this.apiKey,
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 10),
    this.pageSize = 100,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       endpoint = endpoint ?? Uri.parse('https://open.neis.go.kr/hub') {
    _checkPageSize(pageSize, 'pageSize');
  }

  final http.Client _client;
  final bool _ownsClient;

  /// NEIS API key, or `null` to call without one.
  final String? apiKey;

  /// Base address of the NEIS services.
  final Uri endpoint;

  /// Time limit for each request.
  final Duration timeout;

  /// Rows per request, at most 1000.
  ///
  /// NEIS ignores this without an [apiKey]: it sends 5 rows and answers every
  /// page with the same ones, so a keyless client sees 5 rows per call.
  final int pageSize;

  /// Closes the HTTP client this instance created. An injected client is left
  /// open for its owner.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Searches schools by name, region, or office of education.
  ///
  /// Planned schools that NEIS lists before they have a school code are left
  /// out: the other services cannot look them up, and asking with a blank
  /// code returns some other institution's data.
  Future<List<NeisSchool>> schools({
    String? name,
    String? officeCode,
    String? schoolCode,
    String? region,
    int maxPages = 5,
  }) async {
    final rows = await rawRows(NeisService.schoolInfo.path, {
      'SCHUL_NM': name,
      'ATPT_OFCDC_SC_CODE': officeCode,
      'SD_SCHUL_CODE': schoolCode,
      'LCTN_SC_NM': region,
    }, maxPages: maxPages);
    return [
      for (final row in rows)
        if (NeisSchool.fromRow(row) case final school when school.hasCodes)
          school,
    ];
  }

  /// Reads school meals for one day, or for a range when [from] and [to] are
  /// given.
  Future<List<NeisMeal>> meals(
    NeisSchool school, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    int maxPages = 5,
  }) async {
    _checkCodes(school, 'meals');
    final rows = await rawRows(NeisService.mealServiceDietInfo.path, {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'MLSV_YMD': date == null ? null : formatNeisDate(date),
      'MLSV_FROM_YMD': from == null ? null : formatNeisDate(from),
      'MLSV_TO_YMD': to == null ? null : formatNeisDate(to),
    }, maxPages: maxPages);
    return [for (final row in rows) NeisMeal.fromRow(row)];
  }

  /// Reads the school calendar for a day or a range.
  Future<List<NeisScheduleEvent>> schedule(
    NeisSchool school, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    @Deprecated(
      'NEIS ignores AY on SchoolSchedule and returns the whole calendar '
      'either way. Pass from and to instead. Will be removed in 0.2.0.',
    )
    String? year,
    int maxPages = 5,
  }) async {
    _checkCodes(school, 'schedule');
    final rows = await rawRows(NeisService.schoolSchedule.path, {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'AA_YMD': date == null ? null : formatNeisDate(date),
      'AA_FROM_YMD': from == null ? null : formatNeisDate(from),
      'AA_TO_YMD': to == null ? null : formatNeisDate(to),
    }, maxPages: maxPages);
    return [for (final row in rows) NeisScheduleEvent.fromRow(row)];
  }

  /// Reads a class timetable.
  ///
  /// NEIS serves each school level from its own service, so [school] must know
  /// its [NeisSchool.kind]; a school from [schools] always does. Pass [kind]
  /// when you built the school from codes alone.
  ///
  /// NEIS also splits the years in two: the current service holds the recent
  /// school years and an archive holds the older ones, with no overlap. Leave
  /// [archived] unset and the client asks the service that usually holds the
  /// requested year first and the other one when that answer is empty. Set it
  /// to `true` or `false` to read only the archive or only the current
  /// service. Some years are in neither: NEIS has no 2024 timetable for many
  /// schools, and those come back empty.
  ///
  /// Schools write [className] as `1` or `01`, and NEIS only matches the
  /// spelling the school used, so the other spelling is tried when the first
  /// matches nothing.
  ///
  /// Lessons are sorted by date, grade, class, and period.
  Future<List<NeisLesson>> timetable(
    NeisSchool school, {
    DateTime? date,
    DateTime? from,
    DateTime? to,
    String? grade,
    String? className,
    String? year,
    String? semester,
    NeisSchoolKind? kind,
    bool? archived,
    int maxPages = 5,
  }) async {
    _checkCodes(school, 'timetable');
    final level = kind ?? school.kind;
    if (kind == null && level == NeisSchoolKind.other && school.raw.isEmpty) {
      // A school built from codes alone defaults to `other`, which would
      // silently read the high school service.
      throw const NeisException(
        'timetable needs the school level. Pass kind, or use a school from '
        'schools().',
        code: 'missing_parameter',
      );
    }
    final services = switch (archived) {
      true => [level.archiveTimetable],
      false => [level.timetable],
      null when _isPastYear(year, date ?? from) => [
        level.archiveTimetable,
        level.timetable,
      ],
      null => [level.timetable, level.archiveTimetable],
    };
    final classNames = [className, ?_otherClassSpelling(className)];
    for (final service in services) {
      for (final name in classNames) {
        final rows = await rawRows(service.path, {
          'ATPT_OFCDC_SC_CODE': school.officeCode,
          'SD_SCHUL_CODE': school.schoolCode,
          'ALL_TI_YMD': date == null ? null : formatNeisDate(date),
          'TI_FROM_YMD': from == null ? null : formatNeisDate(from),
          'TI_TO_YMD': to == null ? null : formatNeisDate(to),
          'GRADE': grade,
          'CLASS_NM': name,
          'AY': year,
          'SEM': semester,
        }, maxPages: maxPages);
        if (rows.isEmpty) continue;
        return [for (final row in rows) NeisLesson.fromRow(row)]
          ..sort(_compareLessons);
      }
    }
    return const [];
  }

  /// Reads the classes of a school for a school year.
  Future<List<NeisClass>> classes(
    NeisSchool school, {
    String? year,
    String? grade,
    int maxPages = 5,
  }) async {
    _checkCodes(school, 'classes');
    final rows = await rawRows(NeisService.classInfo.path, {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'AY': year,
      'GRADE': grade,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisClass.fromRow(row)];
  }

  /// Searches 학원 and 교습소 registered with one office of education.
  ///
  /// [officeCode] is the only thing NEIS insists on; everything else narrows
  /// the search. Use [NeisOffice] for the codes.
  ///
  /// ```dart
  /// final academies = await neis.academies(
  ///   officeCode: NeisOffice.seoul.code,
  ///   name: '수학',
  /// );
  /// ```
  Future<List<NeisAcademy>> academies({
    required String officeCode,
    String? name,
    String? district,
    String? realm,
    String? level,
    String? courseName,
    String? registrationNumber,
    int maxPages = 5,
  }) async {
    final rows = await rawRows(NeisService.acaInsTiInfo.path, {
      'ATPT_OFCDC_SC_CODE': officeCode,
      'ACA_NM': name,
      'ADMST_ZONE_NM': district,
      'REALM_SC_NM': realm,
      'LE_ORD_NM': level,
      'LE_CRSE_NM': courseName,
      'ACA_ASNUM': registrationNumber,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisAcademy.fromRow(row)];
  }

  /// Reads the departments (학과) of a school, or of a whole office of
  /// education when [school] is omitted.
  Future<List<NeisMajor>> majors({
    NeisSchool? school,
    String? officeCode,
    String? trackName,
    String? dayNightName,
    int maxPages = 5,
  }) async {
    if (school != null) _checkCodes(school, 'majors');
    final rows = await rawRows(NeisService.schoolMajorInfo.path, {
      'ATPT_OFCDC_SC_CODE': officeCode ?? school?.officeCode,
      'SD_SCHUL_CODE': school?.schoolCode,
      'ORD_SC_NM': trackName,
      'DGHT_CRSE_SC_NM': dayNightName,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisMajor.fromRow(row)];
  }

  /// Reads the tracks (계열) of a school, or of a whole office of education
  /// when [school] is omitted.
  Future<List<NeisTrack>> tracks({
    NeisSchool? school,
    String? officeCode,
    String? dayNightName,
    int maxPages = 5,
  }) async {
    if (school != null) _checkCodes(school, 'tracks');
    final rows = await rawRows(NeisService.schulAflcoInfo.path, {
      'ATPT_OFCDC_SC_CODE': officeCode ?? school?.officeCode,
      'SD_SCHUL_CODE': school?.schoolCode,
      'DGHT_CRSE_SC_NM': dayNightName,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisTrack.fromRow(row)];
  }

  /// Reads the classrooms a school's timetable is taught in.
  Future<List<NeisClassroom>> classrooms(
    NeisSchool school, {
    String? year,
    String? semester,
    String? grade,
    String? departmentName,
    int maxPages = 5,
  }) async {
    _checkCodes(school, 'classrooms');
    final rows = await rawRows(NeisService.tiClrmInfo.path, {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'AY': year,
      'SEM': semester,
      'GRADE': grade,
      'DDDEP_NM': departmentName,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisClassroom.fromRow(row)];
  }

  /// Calls any NEIS service and returns its rows.
  ///
  /// Entries of [params] with a `null` value are dropped. Pages are read until
  /// the service runs out of rows or [maxPages] pages have been read, and an
  /// empty list comes back when the query matches nothing.
  ///
  /// NEIS paging needs care: `list_total_count` can be larger than the number
  /// of rows a service actually returns, and some services answer a page
  /// beyond the last one by repeating the first page instead of an empty list.
  /// Paging therefore stops on a short page or a repeated page, so rows are
  /// never duplicated.
  ///
  /// Without an [apiKey] there is no paging to follow: NEIS answers every
  /// page with the same first 5 rows, so a keyless call returns 5 rows at
  /// most and stops after one request.
  ///
  /// At most [maxPages] times [rows] rows come back, 500 with the defaults.
  /// Raise [maxPages] for large result sets such as a whole school year's
  /// timetable.
  Future<List<Map<String, Object?>>> rawRows(
    String service,
    Map<String, Object?> params, {
    int? rows,
    int maxPages = 5,
  }) async {
    if (rows != null) _checkPageSize(rows, 'rows');
    final size = rows ?? pageSize;
    final collected = <Map<String, Object?>>[];
    Map<String, Object?>? firstRowOfPreviousPage;

    for (var page = 1; page <= maxPages; page++) {
      final result = await _request(service, params, page: page, size: size);
      if (result.rows.isEmpty) break;
      if (_sameRow(firstRowOfPreviousPage, result.rows.first)) break;

      collected.addAll(result.rows);
      firstRowOfPreviousPage = result.rows.first;

      // A page shorter than requested is the last one, whatever the reported
      // total says.
      if (result.rows.length < size) break;
      if (collected.length >= result.total) break;
    }
    return collected;
  }

  /// Calls any NEIS service by name and returns its rows.
  ///
  /// Every service NEIS publishes is a constant on [NeisService], so this
  /// reaches the ones without a method of their own:
  ///
  /// ```dart
  /// final rows = await neis.call(NeisService.acaInsTiInfo, {
  ///   'ATPT_OFCDC_SC_CODE': 'B10',
  ///   'ACA_NM': '수학',
  /// });
  /// ```
  ///
  /// A missing [NeisService.requiredParams] entry throws
  /// `missing_parameter` before anything is sent, since NEIS answers that case
  /// with an `ERROR-300` that does not say which parameter it wanted.
  Future<List<NeisRow>> call(
    NeisService service,
    Map<String, Object?> params, {
    int? rows,
    int maxPages = 5,
  }) async {
    final missing = [
      for (final name in service.requiredParams)
        if ('${params[name] ?? ''}'.trim().isEmpty) name,
    ];
    if (missing.isNotEmpty) {
      throw NeisException(
        '${service.path} needs ${missing.join(', ')}.',
        code: 'missing_parameter',
      );
    }
    final result = await rawRows(
      service.path,
      params,
      rows: rows,
      maxPages: maxPages,
    );
    return [for (final row in result) NeisRow(row)];
  }

  static void _checkPageSize(int size, String name) {
    if (size < 1 || size > 1000) throw RangeError.range(size, 1, 1000, name);
  }

  /// Refuses a school without codes: NEIS treats a blank code as no filter
  /// and answers with some other institution's rows.
  static void _checkCodes(NeisSchool school, String method) {
    if (school.hasCodes) return;
    throw NeisException(
      '$method needs a school with an office code and a school code.',
      code: 'missing_parameter',
    );
  }

  /// Whether [year], or the school year of [day], is older than the ones the
  /// current timetable services usually hold: this school year and the one
  /// before. A Korean school year starts in March.
  static bool _isPastYear(String? year, DateTime? day) {
    int schoolYear(DateTime d) => d.month >= 3 ? d.year : d.year - 1;
    final target =
        int.tryParse(year?.trim() ?? '') ??
        (day == null ? null : schoolYear(day));
    return target != null && target < schoolYear(neisToday()) - 1;
  }

  /// `01` for `1` and `1` for `01`, or `null` when [name] is not a class
  /// number written either way.
  static String? _otherClassSpelling(String? name) {
    final text = name?.trim() ?? '';
    if (RegExp(r'^[1-9]$').hasMatch(text)) return '0$text';
    if (RegExp(r'^0[1-9]$').hasMatch(text)) return text.substring(1);
    return null;
  }

  static int _compareLessons(NeisLesson a, NeisLesson b) {
    for (final order in [
      a.date.compareTo(b.date),
      _compareNumbers(a.grade, b.grade),
      _compareNumbers(a.className, b.className),
      a.period.compareTo(b.period),
    ]) {
      if (order != 0) return order;
    }
    return 0;
  }

  /// Compares `2` before `10`, and `01` with `1` as equal.
  static int _compareNumbers(String? a, String? b) {
    final (x, y) = (neisInt(a), neisInt(b));
    if (x != null && y != null) return x.compareTo(y);
    return (a ?? '').compareTo(b ?? '');
  }

  static bool _sameRow(Map<String, Object?>? a, Map<String, Object?> b) {
    if (a == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  Future<({int total, List<Map<String, Object?>> rows})> _request(
    String service,
    Map<String, Object?> params, {
    required int page,
    required int size,
  }) async {
    final query = <String, String>{
      'Type': 'json',
      'pIndex': '$page',
      'pSize': '$size',
      if (apiKey != null && apiKey!.isNotEmpty) 'KEY': apiKey!,
      for (final entry in params.entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    final uri = Uri.parse(
      '${endpoint.toString().replaceFirst(RegExp(r'/$'), '')}/$service',
    ).replace(queryParameters: query);

    Future<http.Response> get() => _client.get(uri).timeout(timeout);
    http.Response response;
    try {
      // A dropped keep-alive connection or a stalled request is common; GET is
      // idempotent, so retry once on a fresh connection. A NEIS error such as
      // ERROR-337 (rate limit) arrives as a normal response and is not retried.
      try {
        response = await get();
      } on http.ClientException {
        response = await get();
      } on TimeoutException {
        response = await get();
      }
    } on TimeoutException {
      throw NeisException(
        'The request to ${uri.host} timed out.',
        code: 'timeout',
      );
    } on http.ClientException catch (error) {
      throw NeisException(
        'The request to ${uri.host} failed: ${error.message}',
        code: 'http_error',
      );
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _parse(service, body, response.statusCode);
  }

  ({int total, List<Map<String, Object?>> rows}) _parse(
    String service,
    String body,
    int statusCode,
  ) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw NeisException(
        'NEIS returned a body that is not JSON (HTTP $statusCode).',
        code: 'invalid_response',
      );
    }
    if (json is! Map<String, Object?>) {
      throw NeisException(
        'NEIS returned JSON that is not an object.',
        code: 'invalid_response',
      );
    }

    // Failures and empty results arrive as a bare RESULT object.
    final result = json['RESULT'];
    if (result is Map) {
      final code = '${result['CODE'] ?? ''}';
      if (neisIsNoData(code)) {
        return (total: 0, rows: const <Map<String, Object?>>[]);
      }
      throw NeisException(
        '${result['MESSAGE'] ?? 'NEIS rejected the request.'}',
        code: neisErrorCodeFor(code),
        resultCode: code,
      );
    }

    // The past-year timetables answer under the name of the current-year
    // service, so the envelope key is not always the service path.
    final key = NeisService.byPath(service)?.envelopeKey ?? service;
    var envelope = json[key] ?? json[service];
    if (envelope is! List) {
      // An unknown service may still answer in the usual shape under some
      // other name; take it when there is only one candidate.
      final lists = json.values.whereType<List>();
      if (lists.length == 1) envelope = lists.first;
    }
    if (envelope is! List || envelope.length < 2) {
      throw NeisException(
        'NEIS returned no $service data.',
        code: 'invalid_response',
      );
    }

    final head = envelope.first;
    var total = 0;
    if (head is Map && head['head'] is List) {
      for (final entry in head['head'] as List) {
        if (entry is! Map) continue;
        if (entry['list_total_count'] != null) {
          total = neisInt(entry['list_total_count']) ?? 0;
        }
        final headResult = entry['RESULT'];
        if (headResult is Map) {
          final code = '${headResult['CODE'] ?? ''}';
          if (neisIsNoData(code)) {
            return (total: 0, rows: const <Map<String, Object?>>[]);
          }
          if (!neisIsOk(code)) {
            throw NeisException(
              '${headResult['MESSAGE'] ?? 'NEIS rejected the request.'}',
              code: neisErrorCodeFor(code),
              resultCode: code,
            );
          }
        }
      }
    }

    final rowsEntry = envelope[1];
    final rows = rowsEntry is Map ? rowsEntry['row'] : null;
    if (rows is! List) return (total: total, rows: const []);
    return (
      total: total,
      rows: [
        for (final row in rows.whereType<Map>())
          <String, Object?>{
            for (final entry in row.entries) '${entry.key}': entry.value,
          },
      ],
    );
  }
}
