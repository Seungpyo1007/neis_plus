import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neis_plus/neis_plus.dart';
import 'package:test/test.dart';

/// Builds a NEIS success envelope for [service] with [rows].
String _page(String service, List<Map<String, Object?>> rows, {int? total}) =>
    jsonEncode({
      service: [
        {
          'head': [
            {'list_total_count': total ?? rows.length},
            {
              'RESULT': {'CODE': 'INFO-000', 'MESSAGE': '정상 처리되었습니다.'},
            },
          ],
        },
        {'row': rows},
      ],
    });

String _result(String code, String message) => jsonEncode({
  'RESULT': {'CODE': code, 'MESSAGE': message},
});

MockClient _serves(String body, {List<Uri>? requests, int status = 200}) =>
    MockClient((request) async {
      requests?.add(request.url);
      return http.Response(
        body,
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

final _seoulHigh = NeisSchool.codes(
  'B10',
  '7010083',
  kind: NeisSchoolKind.high,
);

Matcher _throwsCode(String code) =>
    throwsA(isA<NeisException>().having((e) => e.code, 'code', code));

void main() {
  group('schools', () {
    test('reads a school row', () async {
      final requests = <Uri>[];
      final client = NeisClient(
        client: _serves(
          _page('schoolInfo', [
            {
              'ATPT_OFCDC_SC_CODE': 'B10',
              'ATPT_OFCDC_SC_NM': '서울특별시교육청',
              'SD_SCHUL_CODE': '7010083',
              'SCHUL_NM': '서울고등학교',
              'ENG_SCHUL_NM': 'Seoul High School',
              'SCHUL_KND_SC_NM': '고등학교',
              'LCTN_SC_NM': '서울특별시',
              'FOND_SC_NM': '공립',
              'ORG_RDNMA': '서울특별시 서초구 효령로 197',
              'ORG_TELNO': '02-582-8151',
            },
          ]),
          requests: requests,
        ),
      );

      final schools = await client.schools(name: '서울고등학교');

      expect(schools.single.name, '서울고등학교');
      expect(schools.single.officeCode, 'B10');
      expect(schools.single.schoolCode, '7010083');
      expect(schools.single.kind, NeisSchoolKind.high);
      expect(schools.single.region, '서울특별시');
      expect(schools.single.phone, '02-582-8151');
      expect(requests.single.queryParameters['SCHUL_NM'], '서울고등학교');
      expect(requests.single.path, endsWith('/hub/schoolInfo'));
    });

    test('sends the API key only when there is one', () async {
      final withoutKey = <Uri>[];
      await NeisClient(
        client: _serves(_page('schoolInfo', []), requests: withoutKey),
      ).schools(name: 'a');
      expect(withoutKey.single.queryParameters.containsKey('KEY'), isFalse);

      final withKey = <Uri>[];
      await NeisClient(
        apiKey: 'test-key',
        client: _serves(_page('schoolInfo', []), requests: withKey),
      ).schools(name: 'a');
      expect(withKey.single.queryParameters['KEY'], 'test-key');
    });
  });

  group('meals', () {
    test('parses dishes, allergens, and the date', () async {
      final requests = <Uri>[];
      final client = NeisClient(
        client: _serves(
          _page('mealServiceDietInfo', [
            {
              'MLSV_YMD': '20260612',
              'MMEAL_SC_NM': '중식',
              'DDISH_NM':
                  '찹쌀밥<br/>미역국 (1.5.6)<br/>불고기 (5.6.10.16)<br/>배추김치 (9)',
              'CAL_INFO': '533.5 Kcal',
              'MLSV_FGR': '830',
              'ORPLC_INFO': '쌀 : 국내산',
            },
          ]),
          requests: requests,
        ),
      );

      final meals = await client.meals(_seoulHigh, date: DateTime(2026, 6, 12));
      final meal = meals.single;

      expect(meal.date, DateTime(2026, 6, 12));
      expect(meal.typeName, '중식');
      expect(meal.calories, '533.5 Kcal');
      expect(meal.servings, 830);
      expect(meal.dishes.map((d) => d.name).toList(), [
        '찹쌀밥',
        '미역국',
        '불고기',
        '배추김치',
      ]);
      expect(meal.dishes[1].allergens, [1, 5, 6]);
      expect(meal.dishes[1].allergenNames, ['난류', '대두', '밀']);
      expect(meal.dishes.first.allergens, isEmpty);
      expect(requests.single.queryParameters['MLSV_YMD'], '20260612');
    });

    test('sends a date range', () async {
      final requests = <Uri>[];
      final client = NeisClient(
        client: _serves(_page('mealServiceDietInfo', []), requests: requests),
      );

      await client.meals(
        _seoulHigh,
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 10),
      );

      final query = requests.single.queryParameters;
      expect(query['MLSV_FROM_YMD'], '20260601');
      expect(query['MLSV_TO_YMD'], '20260610');
      expect(query.containsKey('MLSV_YMD'), isFalse);
    });
  });

  group('timetable', () {
    test('picks the service that matches the school level', () async {
      for (final (kind, service) in [
        (NeisSchoolKind.elementary, 'elsTimetable'),
        (NeisSchoolKind.middle, 'misTimetable'),
        (NeisSchoolKind.high, 'hisTimetable'),
        (NeisSchoolKind.special, 'spsTimetable'),
      ]) {
        final requests = <Uri>[];
        final client = NeisClient(
          client: _serves(_page(service, []), requests: requests),
        );

        await client.timetable(
          NeisSchool.codes('B10', '7010083', kind: kind),
          date: DateTime(2026, 6, 12),
          grade: '1',
        );

        expect(requests.single.path, endsWith('/hub/$service'));
      }
    });

    test('sorts lessons by date and period', () async {
      final client = NeisClient(
        client: _serves(
          _page('hisTimetable', [
            {
              'ALL_TI_YMD': '20260612',
              'PERIO': '3',
              'ITRT_CNTNT': '수학',
              'GRADE': '1',
              'CLASS_NM': '2',
            },
            {
              'ALL_TI_YMD': '20260612',
              'PERIO': '1',
              'ITRT_CNTNT': '국어',
              'GRADE': '1',
              'CLASS_NM': '2',
            },
          ]),
        ),
      );

      final lessons = await client.timetable(_seoulHigh, grade: '1');

      expect(lessons.map((l) => l.period).toList(), [1, 3]);
      expect(lessons.first.subject, '국어');
      expect(lessons.first.className, '2');
    });
  });

  test('schedule marks closed days', () async {
    final client = NeisClient(
      client: _serves(
        _page('SchoolSchedule', [
          {'AA_YMD': '20260301', 'EVENT_NM': '삼일절', 'SBTR_DD_SC_NM': '휴업일'},
          {'AA_YMD': '20260302', 'EVENT_NM': '입학식', 'SBTR_DD_SC_NM': '수업일'},
        ]),
      ),
    );

    final events = await client.schedule(
      _seoulHigh,
      from: DateTime(2026, 3),
      to: DateTime(2026, 3, 31),
    );

    expect(events.first.name, '삼일절');
    expect(events.first.isSchoolClosed, isTrue);
    expect(events.last.isSchoolClosed, isFalse);
    expect(events.last.date, DateTime(2026, 3, 2));
  });

  test('classes reads grade and class name', () async {
    final client = NeisClient(
      client: _serves(
        _page('classInfo', [
          {
            'AY': '2026',
            'GRADE': '1',
            'CLASS_NM': '3',
            'SCHUL_CRSE_SC_NM': '고등학교',
          },
        ]),
      ),
    );

    final classes = await client.classes(_seoulHigh, year: '2026');

    expect(classes.single.grade, '1');
    expect(classes.single.name, '3');
    expect(classes.single.courseName, '고등학교');
  });

  group('paging and errors', () {
    test('follows pages until the total is reached', () async {
      final pages = <String>[];
      final client = NeisClient(
        pageSize: 2,
        client: MockClient((request) async {
          final page = request.url.queryParameters['pIndex']!;
          pages.add(page);
          final rows = page == '1'
              ? [
                  {'SCHUL_NM': 'a'},
                  {'SCHUL_NM': 'b'},
                ]
              : [
                  {'SCHUL_NM': 'c'},
                ];
          return http.Response(
            _page('schoolInfo', rows, total: 3),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final schools = await client.schools(name: 'x');

      expect(schools.map((s) => s.name).toList(), ['a', 'b', 'c']);
      expect(pages, ['1', '2']);
    });

    test('stops on a short page even when the total is larger', () async {
      // NEIS reports list_total_count 6 while returning 5 rows, and answers
      // any further page with the same 5 rows.
      var requests = 0;
      final client = NeisClient(
        pageSize: 100,
        client: MockClient((request) async {
          requests++;
          return http.Response(
            _page('hisTimetable', [
              for (var period = 1; period <= 5; period++)
                {'PERIO': '$period', 'ITRT_CNTNT': '과목$period'},
            ], total: 6),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final lessons = await client.timetable(_seoulHigh, grade: '1');

      expect(lessons, hasLength(5));
      expect(requests, 1);
    });

    test('stops when a page repeats the previous one', () async {
      var requests = 0;
      final client = NeisClient(
        pageSize: 2,
        client: MockClient((request) async {
          requests++;
          return http.Response(
            _page('schoolInfo', [
              {'SCHUL_NM': 'a'},
              {'SCHUL_NM': 'b'},
            ], total: 99),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final schools = await client.schools(name: 'x');

      expect(schools.map((s) => s.name).toList(), ['a', 'b']);
      expect(requests, 2);
    });

    test('reports no data as an empty list', () async {
      final client = NeisClient(
        client: _serves(_result('INFO-200', '해당하는 데이터가 없습니다.')),
      );

      expect(await client.schools(name: '없는학교'), isEmpty);
    });

    test('maps NEIS result codes', () async {
      final invalidKey = NeisClient(
        apiKey: 'wrong',
        client: _serves(_result('ERROR-290', '인증키가 유효하지 않습니다.')),
      );
      await expectLater(
        invalidKey.schools(name: 'a'),
        _throwsCode('invalid_key'),
      );

      final missing = NeisClient(
        client: _serves(_result('ERROR-300', '필수 값이 누락되어 있습니다.')),
      );
      await expectLater(
        missing.meals(_seoulHigh),
        _throwsCode('missing_parameter'),
      );

      final limited = NeisClient(
        client: _serves(_result('ERROR-337', '최대 요청 횟수를 초과하였습니다.')),
      );
      await expectLater(limited.schools(name: 'a'), _throwsCode('rate_limit'));

      final broken = NeisClient(client: _serves('<html>500</html>'));
      await expectLater(
        broken.schools(name: 'a'),
        _throwsCode('invalid_response'),
      );
    });

    test('keeps the NEIS message and result code on the exception', () async {
      final client = NeisClient(
        client: _serves(_result('ERROR-290', '인증키가 유효하지 않습니다.')),
      );

      await expectLater(
        client.schools(name: 'a'),
        throwsA(
          isA<NeisException>()
              .having((e) => e.resultCode, 'resultCode', 'ERROR-290')
              .having((e) => e.message, 'message', '인증키가 유효하지 않습니다.'),
        ),
      );
    });

    test('times out and retries a dropped connection', () async {
      final slow = NeisClient(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(slow.schools(name: 'a'), _throwsCode('timeout'));

      var calls = 0;
      final dropping = NeisClient(
        client: MockClient((request) async {
          if (calls++ == 0) {
            throw http.ClientException('Connection closed', request.url);
          }
          return http.Response(
            _page('schoolInfo', [
              {'SCHUL_NM': '서울고등학교'},
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      expect((await dropping.schools(name: 'a')).single.name, '서울고등학교');
      expect(calls, 2);
    });
  });

  group('helpers', () {
    test('parses and formats NEIS dates', () {
      expect(parseNeisDate('20260612'), DateTime(2026, 6, 12));
      expect(parseNeisDate('2026061'), isNull);
      expect(parseNeisDate('bad-date'), isNull);
      expect(formatNeisDate(DateTime(2026, 6, 2)), '20260602');
    });

    test('splits menus with several break tag spellings', () {
      final dishes = parseNeisDishes('밥<br/>국 (1.2)<BR>김치(9)<br />우유 (2)');

      expect(dishes.map((d) => d.name).toList(), ['밥', '국', '김치', '우유']);
      expect(dishes[1].allergens, [1, 2]);
      expect(dishes[2].allergens, [9]);
      expect(dishes[3].allergenNames, ['우유']);
    });

    test('reads school levels from their Korean labels', () {
      expect(NeisSchoolKind.fromLabel('초등학교'), NeisSchoolKind.elementary);
      expect(NeisSchoolKind.fromLabel('중학교'), NeisSchoolKind.middle);
      expect(NeisSchoolKind.fromLabel('고등학교'), NeisSchoolKind.high);
      expect(NeisSchoolKind.fromLabel('특수학교'), NeisSchoolKind.special);
      expect(NeisSchoolKind.fromLabel('각종학교'), NeisSchoolKind.other);
      expect(NeisSchoolKind.fromLabel(null), NeisSchoolKind.other);
    });
  });
}
