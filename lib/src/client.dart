import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exception.dart';
import 'models.dart';

/// Reads school data from the NEIS open API (`open.neis.go.kr`).
///
/// An API key is optional: NEIS answers a limited number of requests without
/// one, which is enough to try things out. Register a key for regular use.
///
/// ```dart
/// final neis = NeisClient();
/// final schools = await neis.schools(name: '서울고등학교');
/// final meals = await neis.meals(schools.first, date: DateTime.now());
/// neis.close();
/// ```
class NeisClient {
  /// Creates a client.
  NeisClient({
    this.apiKey,
    http.Client? client,
    Uri? endpoint,
    this.timeout = const Duration(seconds: 10),
    this.pageSize = 100,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       endpoint = endpoint ?? Uri.parse('https://open.neis.go.kr/hub');

  final http.Client _client;
  final bool _ownsClient;

  /// NEIS API key, or `null` to call without one.
  final String? apiKey;

  /// Base address of the NEIS services.
  final Uri endpoint;

  /// Time limit for each request.
  final Duration timeout;

  /// Rows per request, at most 1000.
  final int pageSize;

  /// Closes the HTTP client this instance created. An injected client is left
  /// open for its owner.
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Searches schools by name, region, or office of education.
  Future<List<NeisSchool>> schools({
    String? name,
    String? officeCode,
    String? schoolCode,
    String? region,
    int maxPages = 5,
  }) async {
    final rows = await rawRows('schoolInfo', {
      'SCHUL_NM': name,
      'ATPT_OFCDC_SC_CODE': officeCode,
      'SD_SCHUL_CODE': schoolCode,
      'LCTN_SC_NM': region,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisSchool.fromRow(row)];
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
    final rows = await rawRows('mealServiceDietInfo', {
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
    String? year,
    int maxPages = 5,
  }) async {
    final rows = await rawRows('SchoolSchedule', {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'AA_YMD': date == null ? null : formatNeisDate(date),
      'AA_FROM_YMD': from == null ? null : formatNeisDate(from),
      'AA_TO_YMD': to == null ? null : formatNeisDate(to),
      'AY': year,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisScheduleEvent.fromRow(row)];
  }

  /// Reads a class timetable.
  ///
  /// NEIS serves each school level from its own service, so [school] must know
  /// its [NeisSchool.kind]; a school from [schools] always does. Pass [kind]
  /// when you built the school from codes alone.
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
    int maxPages = 5,
  }) async {
    final rows = await rawRows((kind ?? school.kind).timetableService, {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'ALL_TI_YMD': date == null ? null : formatNeisDate(date),
      'TI_FROM_YMD': from == null ? null : formatNeisDate(from),
      'TI_TO_YMD': to == null ? null : formatNeisDate(to),
      'GRADE': grade,
      'CLASS_NM': className,
      'AY': year,
      'SEM': semester,
    }, maxPages: maxPages);
    final lessons = [for (final row in rows) NeisLesson.fromRow(row)]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.period.compareTo(b.period);
      });
    return lessons;
  }

  /// Reads the classes of a school for a school year.
  Future<List<NeisClass>> classes(
    NeisSchool school, {
    String? year,
    String? grade,
    int maxPages = 5,
  }) async {
    final rows = await rawRows('classInfo', {
      'ATPT_OFCDC_SC_CODE': school.officeCode,
      'SD_SCHUL_CODE': school.schoolCode,
      'AY': year,
      'GRADE': grade,
    }, maxPages: maxPages);
    return [for (final row in rows) NeisClass.fromRow(row)];
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
  Future<List<Map<String, Object?>>> rawRows(
    String service,
    Map<String, Object?> params, {
    int? rows,
    int maxPages = 5,
  }) async {
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
    final http.Response response;
    try {
      // A dropped keep-alive connection is common; GET is idempotent, so retry
      // once on a fresh connection.
      response = await get().onError<http.ClientException>((_, _) => get());
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

    final envelope = json[service];
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
          total = int.tryParse('${entry['list_total_count']}') ?? 0;
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
