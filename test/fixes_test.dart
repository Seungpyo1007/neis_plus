import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neis_plus/neis_plus.dart';
import 'package:test/test.dart';

String _page(String service, List<Map<String, Object?>> rows) => jsonEncode({
  service: [
    {
      'head': [
        {'list_total_count': rows.length},
        {
          'RESULT': {'CODE': 'INFO-000', 'MESSAGE': '정상 처리되었습니다.'},
        },
      ],
    },
    {'row': rows},
  ],
});

String _result(String code) => jsonEncode({
  'RESULT': {'CODE': code, 'MESSAGE': 'NEIS says $code'},
});

final _noData = _result('INFO-200');

http.Response _json(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _seoulHigh = NeisSchool.codes(
  'B10',
  '7010083',
  kind: NeisSchoolKind.high,
);

Matcher _throwsCode(String code) =>
    throwsA(isA<NeisException>().having((e) => e.code, 'code', code));

/// Records [close] so tests can tell whether the client closed it.
class _TrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream.value(utf8.encode(_noData)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  @override
  void close() => closed = true;
}

void main() {
  group('numbers NEIS sends as JSON numbers', () {
    test('reads servings sent as 780.00', () async {
      // The real response: MLSV_FGR is a JSON number, which the VM decodes
      // as the double 780.0.
      const body =
          '{"mealServiceDietInfo":[{"head":[{"list_total_count":1},'
          '{"RESULT":{"CODE":"INFO-000","MESSAGE":"ok"}}]},'
          '{"row":[{"MLSV_YMD":"20261020","MMEAL_SC_NM":"중식",'
          '"DDISH_NM":"밥","MLSV_FGR":780.00}]}]}';
      final client = NeisClient(client: MockClient((_) async => _json(body)));

      final meal = (await client.meals(_seoulHigh)).single;

      expect(meal.servings, 780);
    });

    test('NeisRow reads numbers in every shape', () {
      const row = NeisRow({
        'a': 780.0,
        'b': '780.00',
        'c': 780,
        'd': '780',
        'e': 1.5,
        'f': 'x',
        'g': ' ',
      });

      for (final field in ['a', 'b', 'c', 'd']) {
        expect(row.integer(field), 780, reason: field);
        expect(row.number(field), 780.0, reason: field);
      }
      expect(row.integer('e'), isNull);
      expect(row.number('e'), 1.5);
      expect(row.integer('f'), isNull);
      expect(row.number('g'), isNull);
      expect(row.integer('missing'), isNull);
    });
  });

  group('schools without codes', () {
    test('schools leaves out planned schools with a blank code', () async {
      final client = NeisClient(
        client: MockClient(
          (_) async => _json(
            _page('schoolInfo', [
              {
                'ATPT_OFCDC_SC_CODE': 'B10',
                'SD_SCHUL_CODE': '       ',
                'SCHUL_NM': '(가칭)서울산빛초등학교',
              },
              {
                'ATPT_OFCDC_SC_CODE': 'B10 ',
                'SD_SCHUL_CODE': ' 7010083',
                'SCHUL_NM': '서울고등학교',
              },
            ]),
          ),
        ),
      );

      final schools = await client.schools(name: '서울');

      expect(schools.map((s) => s.name), ['서울고등학교']);
      expect(schools.single.officeCode, 'B10');
      expect(schools.single.schoolCode, '7010083');
    });

    test('school services refuse a school without codes', () async {
      var requests = 0;
      final client = NeisClient(
        client: MockClient((_) async {
          requests++;
          return _json(_noData);
        }),
      );
      const blank = NeisSchool.codes(
        'B10',
        '       ',
        kind: NeisSchoolKind.high,
      );

      for (final call in <Future<Object?> Function()>[
        () => client.meals(blank),
        () => client.schedule(blank),
        () => client.timetable(blank),
        () => client.classes(blank),
        () => client.classrooms(blank),
        () => client.majors(school: blank),
        () => client.tracks(school: blank),
      ]) {
        await expectLater(call(), _throwsCode('missing_parameter'));
      }
      expect(requests, 0);
      expect(blank.hasCodes, isFalse);
      expect(_seoulHigh.hasCodes, isTrue);
    });
  });

  group('timetable years and class names', () {
    test('asks the archive when the current service is empty', () async {
      final paths = <String>[];
      final client = NeisClient(
        client: MockClient((request) async {
          paths.add(request.url.pathSegments.last);
          return _json(
            request.url.path.endsWith('bgs')
                ? _page('hisTimetable', [
                    {
                      'ALL_TI_YMD': '20250514',
                      'PERIO': '1',
                      'ITRT_CNTNT': '국어',
                    },
                  ])
                : _noData,
          );
        }),
      );

      final lessons = await client.timetable(_seoulHigh, grade: '1');

      expect(lessons.single.subject, '국어');
      expect(paths, ['hisTimetable', 'hisTimetablebgs']);
    });

    test('asks the archive first for an old school year', () async {
      final paths = <String>[];
      final client = NeisClient(
        client: MockClient((request) async {
          paths.add(request.url.pathSegments.last);
          return _json(_noData);
        }),
      );

      expect(await client.timetable(_seoulHigh, year: '2010'), isEmpty);
      expect(paths, ['hisTimetablebgs', 'hisTimetable']);

      paths.clear();
      await client.timetable(_seoulHigh, date: DateTime(2011, 2, 28));
      expect(paths.first, 'hisTimetablebgs');
    });

    test('tries the other class name spelling', () async {
      final asked = <String>[];
      final client = NeisClient(
        client: MockClient((request) async {
          final query = request.url.queryParameters;
          asked.add('${request.url.pathSegments.last} ${query['CLASS_NM']}');
          // Like 가락고: the archive only matches the zero-padded name.
          final matches =
              request.url.path.endsWith('bgs') && query['CLASS_NM'] == '01';
          return _json(
            matches
                ? _page('hisTimetable', [
                    {
                      'ALL_TI_YMD': '20230313',
                      'PERIO': '1',
                      'ITRT_CNTNT': '수학',
                      'CLASS_NM': '01',
                    },
                  ])
                : _noData,
          );
        }),
      );

      final lessons = await client.timetable(
        _seoulHigh,
        year: '2023',
        grade: '1',
        className: '1',
      );

      expect(lessons.single.className, '01');
      expect(asked, ['hisTimetablebgs 1', 'hisTimetablebgs 01']);
    });

    test('archived true or false reads only that service', () async {
      for (final (archived, path) in [
        (true, 'hisTimetablebgs'),
        (false, 'hisTimetable'),
      ]) {
        final paths = <String>[];
        final client = NeisClient(
          client: MockClient((request) async {
            paths.add(request.url.pathSegments.last);
            return _json(_noData);
          }),
        );

        await client.timetable(_seoulHigh, archived: archived);

        expect(paths, [path]);
      }
    });

    test('refuses a school built from codes without a kind', () async {
      var requests = 0;
      final client = NeisClient(
        client: MockClient((_) async {
          requests++;
          return _json(_noData);
        }),
      );

      await expectLater(
        client.timetable(const NeisSchool.codes('B10', '7010083')),
        _throwsCode('missing_parameter'),
      );
      expect(requests, 0);

      // Passing kind, or a school read from schoolInfo, is fine.
      await client.timetable(
        const NeisSchool.codes('B10', '7010083'),
        kind: NeisSchoolKind.high,
      );
      await client.timetable(
        NeisSchool.fromRow(const {
          'ATPT_OFCDC_SC_CODE': 'B10',
          'SD_SCHUL_CODE': '7010001',
          'SCHUL_KND_SC_NM': '각종학교',
        }),
      );
      expect(requests, 4);
    });

    test('sorts several classes by grade, class, then period', () async {
      Map<String, Object?> lesson(String grade, String className, int period) =>
          {
            'ALL_TI_YMD': '20260612',
            'GRADE': grade,
            'CLASS_NM': className,
            'PERIO': '$period',
            'ITRT_CNTNT': '$grade-$className-$period',
          };
      final client = NeisClient(
        client: MockClient(
          (_) async => _json(
            _page('hisTimetable', [
              lesson('1', '10', 1),
              lesson('1', '2', 2),
              lesson('2', '1', 1),
              lesson('1', '2', 1),
            ]),
          ),
        ),
      );

      final lessons = await client.timetable(_seoulHigh);

      expect(lessons.map((l) => l.subject), [
        '1-2-1',
        '1-2-2',
        '1-10-1',
        '2-1-1',
      ]);
    });
  });

  test('public holidays count as closed', () {
    NeisScheduleEvent event(String kind) => NeisScheduleEvent.fromRow({
      'AA_YMD': '20261003',
      'SBTR_DD_SC_NM': kind,
    });

    expect(event('공휴일').isSchoolClosed, isTrue);
    expect(event('휴업일').isSchoolClosed, isTrue);
    expect(event('해당없음').isSchoolClosed, isFalse);
  });

  test('page sizes outside 1 to 1000 are rejected', () async {
    expect(() => NeisClient(pageSize: 0), throwsRangeError);
    expect(() => NeisClient(pageSize: 1001), throwsRangeError);
    expect(NeisClient(pageSize: 1000).pageSize, 1000);

    final client = NeisClient(client: MockClient((_) async => _json(_noData)));
    expect(
      () => client.rawRows('schoolInfo', {}, rows: 1001),
      throwsRangeError,
    );
  });

  group('dates', () {
    test('rejects dates that do not exist', () {
      expect(parseNeisDate('20261340'), isNull);
      expect(parseNeisDate('20260230'), isNull);
      expect(parseNeisDate('2026a612'), isNull);
      expect(parseNeisDate('+2026061'), isNull);
      expect(parseNeisDate('20240229'), DateTime(2024, 2, 29));
      expect(parseNeisDate(' 20261020 '), DateTime(2026, 10, 20));
    });

    test('neisToday is the date in Korea', () {
      // 16:00 UTC is 01:00 the next day in Korea.
      expect(neisToday(DateTime.utc(2026, 6, 11, 16)), DateTime(2026, 6, 12));
      expect(
        neisToday(DateTime.utc(2026, 6, 12, 14, 59)),
        DateTime(2026, 6, 12),
      );
      expect(neisToday(DateTime.utc(2026, 12, 31, 15)), DateTime(2027));
    });
  });

  group('retries', () {
    test('retries a request that timed out once', () async {
      var calls = 0;
      final client = NeisClient(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          if (calls++ == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
          }
          return _json(_noData);
        }),
      );

      expect(await client.schools(name: 'a'), isEmpty);
      expect(calls, 2);
    });

    test('does not retry a rate limit answer', () async {
      var calls = 0;
      final client = NeisClient(
        client: MockClient((_) async {
          calls++;
          return _json(_result('ERROR-337'));
        }),
      );

      await expectLater(client.schools(name: 'a'), _throwsCode('rate_limit'));
      expect(calls, 1);
    });

    test('reports a connection that fails twice as http_error', () async {
      var calls = 0;
      final client = NeisClient(
        client: MockClient((request) async {
          calls++;
          throw http.ClientException('Connection closed', request.url);
        }),
      );

      await expectLater(client.schools(name: 'a'), _throwsCode('http_error'));
      expect(calls, 2);
    });
  });

  group('meal and school text', () {
    test('splits nutrients and origin into lines', () {
      final meal = NeisMeal.fromRow(const {
        'MLSV_YMD': '20261020',
        'NTR_INFO': '탄수화물(g) : 95.1<br/>단백질(g) : 30.2<br/>',
        'ORPLC_INFO': '쌀 : 국내산<br/>김치류 : 국내산',
      });

      expect(meal.nutrients, '탄수화물(g) : 95.1\n단백질(g) : 30.2');
      expect(meal.origin, '쌀 : 국내산\n김치류 : 국내산');
    });

    test('drops a bare http:// website', () {
      NeisSchool school(String website) =>
          NeisSchool.fromRow({'HMPG_ADRES': website});

      expect(school('http://').website, isNull);
      expect(school('https://').website, isNull);
      expect(school(' ').website, isNull);
      expect(school('http://seoul.hs.kr').website, 'http://seoul.hs.kr');
    });
  });

  test('close closes only a client the instance created', () {
    final injected = _TrackingClient();
    NeisClient(client: injected).close();
    expect(injected.closed, isFalse);

    // An owned client is closed; closing twice is harmless.
    final owned = NeisClient()..close();
    owned.close();
  });

  group('errors', () {
    test('maps the remaining NEIS result codes', () async {
      for (final (resultCode, code) in [
        ('INFO-300', 'key_disabled'),
        ('ERROR-310', 'unknown_service'),
        ('ERROR-333', 'invalid_parameter'),
        ('ERROR-336', 'too_many_rows'),
        ('ERROR-500', 'server_error'),
        ('ERROR-999', 'service_error'),
      ]) {
        final client = NeisClient(
          client: MockClient((_) async => _json(_result(resultCode))),
        );
        await expectLater(
          client.schools(name: 'a'),
          throwsA(
            isA<NeisException>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.resultCode, 'resultCode', resultCode),
          ),
        );
      }
    });

    test('reads an error inside the envelope head', () async {
      final body = jsonEncode({
        'schoolInfo': [
          {
            'head': [
              {'list_total_count': 0},
              {
                'RESULT': {'CODE': 'ERROR-290', 'MESSAGE': '인증키가 유효하지 않습니다.'},
              },
            ],
          },
          {'row': <Object?>[]},
        ],
      });
      final client = NeisClient(client: MockClient((_) async => _json(body)));

      await expectLater(client.schools(name: 'a'), _throwsCode('invalid_key'));
    });

    test('rejects JSON that is not an object', () async {
      final client = NeisClient(client: MockClient((_) async => _json('[]')));

      await expectLater(
        client.schools(name: 'a'),
        _throwsCode('invalid_response'),
      );
    });
  });
}
