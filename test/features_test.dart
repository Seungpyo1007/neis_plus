import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neis_plus/neis_plus.dart';
import 'package:test/test.dart';

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

final _noData = jsonEncode({
  'RESULT': {'CODE': 'INFO-200', 'MESSAGE': '해당하는 데이터가 없습니다.'},
});

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

/// A breakfast row as 경북과학고등학교 published it, trimmed.
const _breakfast = <String, Object?>{
  'ATPT_OFCDC_SC_CODE': 'R10',
  'SD_SCHUL_CODE': '8750078',
  'SCHUL_NM': '경북과학고등학교',
  'MMEAL_SC_CODE': '1',
  'MMEAL_SC_NM': '조식',
  'MLSV_YMD': '20261001',
  'MLSV_FGR': 160.0,
  'DDISH_NM':
      '영양닭죽-(과) (5.6.15)<br/>폴드포크(과) (1.2.5.6.10.12.13.15.16.18)'
      '<br/>단호박꿀찜(과) (13)<br/>깍두기(과) (9)<br/>시리얼+우유(과) (2.5.6)',
  'CAL_INFO': '612.0 Kcal',
  'NTR_INFO':
      '탄수화물(g) : 77.7<br/>단백질(g) : 26.9<br/>지방(g) : 22.1<br/>'
      '비타민A(R.E) : 445.1<br/>티아민(mg) : 0.5<br/>리보플라빈(mg) : 1.0<br/>'
      '비타민C(mg) : 50.9<br/>칼슘(mg) : 297.6<br/>철분(mg) : 3.7',
  'ORPLC_INFO':
      '쇠고기(종류) : 국내산(한우)<br/>돼지고기 식육가공품 : (예외 베이컨돈육,스팸: '
      '국산/ 외국산-미국,캐나다,스페인 등)<br/>콩 가공품 : 콩:수입<br/>비고 : ',
};

void main() {
  group('NeisPage and paging', () {
    test('reports a complete answer as not truncated', () async {
      final client = NeisClient(
        apiKey: 'key',
        pageSize: 2,
        client: MockClient((request) async {
          final page = request.url.queryParameters['pIndex'];
          return _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': 'a$page'},
              if (page == '1') {'ACA_NM': 'b$page'},
            ], total: 3),
          );
        }),
      );

      final page = await client.academiesPage(officeCode: 'B10');

      expect(page.items.map((a) => a.name), ['a1', 'b1', 'a2']);
      expect(page.total, 3);
      expect(page.truncated, isFalse);
    });

    test('reports a cut at maxPages as truncated', () async {
      var requests = 0;
      final client = NeisClient(
        apiKey: 'key',
        pageSize: 2,
        client: MockClient((request) async {
          requests++;
          final page = request.url.queryParameters['pIndex'];
          return _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': 'a$page'},
              {'ACA_NM': 'b$page'},
            ], total: 10),
          );
        }),
      );

      final page = await client.academiesPage(officeCode: 'B10', maxPages: 2);

      expect(requests, 2);
      expect(page.items, hasLength(4));
      expect(page.total, 10);
      expect(page.truncated, isTrue);
      expect(page.toString(), 'NeisPage(4 of 10, truncated)');
    });

    test('reports a keyless answer below the total as truncated', () async {
      // Without a key NEIS sends 5 rows whatever pSize asks for, which looks
      // like a short last page.
      final client = NeisClient(
        client: MockClient(
          (_) async => _json(
            _page('schoolInfo', [
              for (var i = 0; i < 5; i++)
                {
                  'ATPT_OFCDC_SC_CODE': 'B10',
                  'SD_SCHUL_CODE': '701000$i',
                  'SCHUL_NM': '학교$i',
                },
            ], total: 2550),
          ),
        ),
      );

      final page = await client.schoolsPage(name: '고등학교');

      expect(page.items, hasLength(5));
      expect(page.total, 2550);
      expect(page.truncated, isTrue);
    });

    test('list methods still return plain lists', () async {
      final client = NeisClient(
        client: MockClient(
          (_) async => _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': '수학학원'},
            ]),
          ),
        ),
      );

      final academies = await client.academies(officeCode: 'B10');

      expect(academies.single.name, '수학학원');
    });

    test('callPage checks required parameters', () async {
      final client = NeisClient(client: MockClient((_) async => _json('')));

      expect(
        () => client.callPage(NeisService.mealServiceDietInfo, {}),
        throwsA(
          isA<NeisException>().having(
            (e) => e.code,
            'code',
            NeisErrorCode.missingParameter,
          ),
        ),
      );
    });

    test('NeisPage.map keeps the counts', () {
      const page = NeisPage<int>([1, 2], total: 9, truncated: true);

      final mapped = page.map((n) => '$n');

      expect(mapped.items, ['1', '2']);
      expect(mapped.total, 9);
      expect(mapped.truncated, isTrue);
    });
  });

  group('stream', () {
    test('reads every page lazily', () async {
      final pages = <String>[];
      final client = NeisClient(
        apiKey: 'key',
        pageSize: 2,
        client: MockClient((request) async {
          final page = request.url.queryParameters['pIndex']!;
          pages.add(page);
          return _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': 'a$page'},
              if (page != '3') {'ACA_NM': 'b$page'},
            ], total: 5),
          );
        }),
      );

      final names = await client
          .stream(NeisService.acaInsTiInfo, {'ATPT_OFCDC_SC_CODE': 'B10'})
          .map((row) => row.text('ACA_NM'))
          .toList();

      expect(names, ['a1', 'b1', 'a2', 'b2', 'a3']);
      expect(pages, ['1', '2', '3']);
    });

    test('stops requesting once the subscription is cancelled', () async {
      var requests = 0;
      final client = NeisClient(
        apiKey: 'key',
        pageSize: 2,
        client: MockClient((request) async {
          requests++;
          final page = request.url.queryParameters['pIndex'];
          return _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': 'a$page'},
              {'ACA_NM': 'b$page'},
            ], total: 1000),
          );
        }),
      );

      final first = await client
          .stream(NeisService.acaInsTiInfo, {'ATPT_OFCDC_SC_CODE': 'B10'})
          .take(3)
          .toList();

      expect(first, hasLength(3));
      expect(requests, 2);
    });

    test('stops at maxPages', () async {
      final client = NeisClient(
        apiKey: 'key',
        pageSize: 1,
        client: MockClient((request) async {
          final page = request.url.queryParameters['pIndex'];
          return _json(
            _page('acaInsTiInfo', [
              {'ACA_NM': 'a$page'},
            ], total: 100),
          );
        }),
      );

      final rows = await client.stream(NeisService.acaInsTiInfo, {
        'ATPT_OFCDC_SC_CODE': 'B10',
      }, maxPages: 3).toList();

      expect(rows, hasLength(3));
    });

    test('ends after one page without a key', () async {
      var requests = 0;
      final client = NeisClient(
        client: MockClient((_) async {
          requests++;
          return _json(
            _page('acaInsTiInfo', [
              for (var i = 0; i < 5; i++) {'ACA_NM': 'a$i'},
            ], total: 25512),
          );
        }),
      );

      final rows = await client.stream(NeisService.acaInsTiInfo, {
        'ATPT_OFCDC_SC_CODE': 'B10',
      }).toList();

      expect(rows, hasLength(5));
      // The first page is short against pSize, so no second request.
      expect(requests, 1);
    });
  });

  group('meal helpers', () {
    test('filters by meal type with MMEAL_SC_CODE', () async {
      late Uri asked;
      final client = NeisClient(
        client: MockClient((request) async {
          asked = request.url;
          return _json(_page('mealServiceDietInfo', [_breakfast]));
        }),
      );

      final meals = await client.meals(
        _seoulHigh,
        date: DateTime(2026, 10, 1),
        type: NeisMealType.breakfast,
      );

      expect(asked.queryParameters['MMEAL_SC_CODE'], '1');
      expect(meals.single.type, NeisMealType.breakfast);
      expect(meals.single.schoolName, '경북과학고등학교');
    });

    test('todayMeals asks for the Korean date', () async {
      late Uri asked;
      final client = NeisClient(
        client: MockClient((request) async {
          asked = request.url;
          return _json(_noData);
        }),
      );

      // 2026-10-21 16:30 UTC is 2026-10-22 01:30 in Korea.
      await client.todayMeals(
        _seoulHigh,
        type: NeisMealType.lunch,
        now: DateTime.utc(2026, 10, 21, 16, 30),
      );

      expect(asked.queryParameters['MLSV_YMD'], '20261022');
      expect(asked.queryParameters['MMEAL_SC_CODE'], '2');
    });

    test('reads the meal type from the name when the code is missing', () {
      final meal = NeisMeal.fromRow(const {'MMEAL_SC_NM': '석식'});

      expect(meal.type, NeisMealType.dinner);
      expect(NeisMealType.fromCode('2'), NeisMealType.lunch);
      expect(NeisMealType.fromCode(2.0), NeisMealType.lunch);
      expect(NeisMealType.fromCode('9'), isNull);
    });

    test('parses calories, nutrients, and origins', () {
      final meal = NeisMeal.fromRow(_breakfast);

      expect(meal.kcal, 612.0);
      expect(meal.nutrition, hasLength(9));
      expect(
        meal.nutrition['탄수화물'],
        const NeisNutrient('탄수화물', 77.7, unit: 'g'),
      );
      expect(meal.nutrition['비타민A']!.unit, 'R.E');
      expect(meal.nutrition['철분']!.value, 3.7);
      expect(meal.origins, const [
        NeisOrigin('쇠고기(종류)', '국내산(한우)'),
        NeisOrigin('돼지고기 식육가공품', '(예외 베이컨돈육,스팸: 국산/ 외국산-미국,캐나다,스페인 등)'),
        NeisOrigin('콩 가공품', '콩:수입'),
      ]);
    });

    test('parses calories and nutrients from loose text', () {
      expect(parseNeisCalories('533.5 Kcal'), 533.5);
      expect(parseNeisCalories('1031 kcal'), 1031);
      expect(parseNeisCalories(null), isNull);
      expect(parseNeisCalories('없음'), isNull);
      expect(parseNeisNutrients('단백질(g) : 41.8\n지방 : 15'), {
        '단백질': const NeisNutrient('단백질', 41.8, unit: 'g'),
        '지방': const NeisNutrient('지방', 15),
      });
      expect(parseNeisNutrients('비고 : 없음'), isEmpty);
      expect(parseNeisOrigins('비고 : <br/>쌀 : 국내산'), const [
        NeisOrigin('쌀', '국내산'),
      ]);
    });

    test('decodes allergens and filters dishes', () {
      final meal = NeisMeal.fromRow(_breakfast);

      expect(meal.dishes.first.allergenKinds, const [
        NeisAllergen.soybeans,
        NeisAllergen.wheat,
        NeisAllergen.chicken,
      ]);
      expect(meal.containsAllergen(NeisAllergen.milk), isTrue);
      expect(meal.containsAllergen(NeisAllergen.peanuts), isFalse);
      expect(
        meal.containsAnyAllergen(const [
          NeisAllergen.peanuts,
          NeisAllergen.shrimp,
        ]),
        isTrue,
      );
      expect(
        meal
            .dishesWithout(const [NeisAllergen.milk, NeisAllergen.pork])
            .map((dish) => dish.cleanName),
        ['영양닭죽', '단호박꿀찜', '깍두기'],
      );
      expect(meal.allergens, contains(NeisAllergen.shellfish));
      expect(NeisAllergen.fromNumber(19), NeisAllergen.pineNuts);
      expect(NeisAllergen.fromNumber(20), isNull);
      expect(NeisAllergen.values.map((a) => a.label), neisAllergens);
    });
  });

  group('dish markers', () {
    // Every case is a dish name NEIS published in September or October 2026.
    const cases = {
      '영양닭죽-(과)': ('영양닭죽', ['(과)']),
      '배추김치(가)*': ('배추김치', ['*', '(가)']),
      '*쌀밥': ('쌀밥', ['*']),
      '* 오이고추무침': ('오이고추무침', ['*']),
      '@꽃게된장국': ('꽃게된장국', ['@']),
      'o돼지불고기': ('돼지불고기', ['o']),
      '*토마토스파게티*': ('토마토스파게티', ['*', '*']),
      '버섯매운탕**': ('버섯매운탕', ['**']),
      '십곡밥s': ('십곡밥', ['s']),
      '참나물무침m': ('참나물무침', ['m']),
      '시저샐러드/레몬요거트크림D': ('시저샐러드/레몬요거트크림', ['D']),
      '깍두기1': ('깍두기', ['1']),
      '호박죽-1': ('호박죽', ['-1']),
      '파김치-1(자율)': ('파김치', ['(자율)', '-1']),
      '콩나물무침(배식)(점심)': ('콩나물무침', ['(점심)', '(배식)']),
      '양념장(친.생선)': ('양념장', ['(친.생선)']),
      '찰보리밥(중)': ('찰보리밥', ['(중)']),
      '[기후동행식단] 야채비빔밥&계란프라이': ('야채비빔밥&계란프라이', ['[기후동행식단]']),
      '닭개장(m1)': ('닭개장', ['(m1)']),
    };
    for (final MapEntry(key: dish, value: (name, markers)) in cases.entries) {
      test('cleans $dish', () {
        final split = splitNeisDishMarkers(dish);
        expect(split.name, name);
        expect(split.markers, markers);
        expect(NeisDish(dish).cleanName, name);
      });
    }

    test('keeps parentheses that describe the dish', () {
      for (final dish in [
        '춘천산사과(홍로)',
        '파인애플(생과)',
        '*LA갈비구이(돈육)',
        '짜먹는요구르트(포도맛)',
        '배추김치(포기)',
        '치즈스틱(2)',
        '미니크로칸슈(우유/초코)',
        '혼합잡곡밥(종촌)',
      ]) {
        expect(
          splitNeisDishMarkers(dish).name,
          dish.replaceFirst('*', ''),
          reason: dish,
        );
      }
    });

    test('keeps uppercase prefixes and a name that is only a marker', () {
      expect(splitNeisDishMarkers('LA갈비').name, 'LA갈비');
      expect(splitNeisDishMarkers('*').name, '*');
      expect(splitNeisDishMarkers('  밥  ').name, '밥');
    });
  });

  group('school search', () {
    NeisSchool school(String name, String code) => NeisSchool(
      officeCode: 'B10',
      schoolCode: code,
      name: name,
      kind: NeisSchoolKind.high,
    );

    test('expands short names', () {
      expect(expandNeisSchoolName('서울고'), '서울고등학교');
      expect(expandNeisSchoolName('경덕여고'), '경덕여자고등학교');
      expect(expandNeisSchoolName('가락중'), '가락중학교');
      expect(expandNeisSchoolName('수원외고'), '수원외국어고등학교');
      expect(expandNeisSchoolName('서울 고'), '서울고등학교');
      expect(expandNeisSchoolName('서울고등학교'), isNull);
      expect(expandNeisSchoolName('고'), isNull);
    });

    test('ranks exact, expanded, prefix, then contained names', () {
      final ranked = rankNeisSchools('서울고', [
        school('서울고명초등학교', '1'),
        school('신서울고등학교', '2'),
        school('서울고등학교', '3'),
        school('서울고덕초등학교', '4'),
      ]);

      expect(ranked.map((s) => s.name), [
        '서울고등학교',
        '서울고덕초등학교',
        '서울고명초등학교',
        '신서울고등학교',
      ]);
      expect(
        rankNeisSchools('가락고등학교', [
          school('가락고등학교부설', '1'),
          school('가락고등학교', '2'),
        ]).first.name,
        '가락고등학교',
      );
    });

    test('findSchools searches the short and the full name', () async {
      final asked = <String?>[];
      final client = NeisClient(
        client: MockClient((request) async {
          final name = request.url.queryParameters['SCHUL_NM'];
          asked.add(name);
          return _json(
            name == '경덕여자고등학교'
                ? _page('schoolInfo', [
                    {
                      'ATPT_OFCDC_SC_CODE': 'D10',
                      'SD_SCHUL_CODE': '7240053',
                      'SCHUL_NM': '경덕여자고등학교',
                      'SCHUL_KND_SC_NM': '고등학교',
                    },
                  ])
                : _noData,
          );
        }),
      );

      final found = await client.findSchools('경덕여고');

      expect(asked, ['경덕여고', '경덕여자고등학교']);
      expect(found.single.schoolCode, '7240053');
    });

    test('findSchool returns the best match or null', () async {
      final client = NeisClient(
        client: MockClient(
          (request) async => _json(
            request.url.queryParameters['SCHUL_NM'] == '없는학교'
                ? _noData
                : _page('schoolInfo', [
                    {
                      'ATPT_OFCDC_SC_CODE': 'B10',
                      'SD_SCHUL_CODE': '7010084',
                      'SCHUL_NM': '서울고덕초등학교',
                    },
                    {
                      'ATPT_OFCDC_SC_CODE': 'B10',
                      'SD_SCHUL_CODE': '7010083',
                      'SCHUL_NM': '서울고등학교',
                    },
                  ]),
          ),
        ),
      );

      expect((await client.findSchool('서울고'))!.schoolCode, '7010083');
      expect(await client.findSchool('없는학교'), isNull);
      expect(() => client.findSchools('  '), throwsA(isA<NeisException>()));
    });
  });

  group('filters', () {
    late Uri asked;
    late NeisClient client;
    setUp(() {
      client = NeisClient(
        client: MockClient((request) async {
          asked = request.url;
          return _json(_noData);
        }),
      );
    });

    test('schools sends level and foundation', () async {
      await client.schools(kind: NeisSchoolKind.middle, foundation: '사립');
      expect(asked.queryParameters['SCHUL_KND_SC_NM'], '중학교');
      expect(asked.queryParameters['FOND_SC_NM'], '사립');

      await client.schools(kind: NeisSchoolKind.other);
      expect(asked.queryParameters.containsKey('SCHUL_KND_SC_NM'), isFalse);
    });

    test('schedule, classes, and classrooms send course filters', () async {
      await client.schedule(_seoulHigh, courseName: '고등학교', dayNightName: '주간');
      expect(asked.queryParameters['SCHUL_CRSE_SC_NM'], '고등학교');
      expect(asked.queryParameters['DGHT_CRSE_SC_NM'], '주간');

      await client.classes(
        _seoulHigh,
        courseName: '고등학교',
        dayNightName: '야간',
        trackName: '일반계',
        departmentName: '일반학과',
      );
      expect(asked.queryParameters, containsPair('ORD_SC_NM', '일반계'));
      expect(asked.queryParameters, containsPair('DDDEP_NM', '일반학과'));
      expect(asked.queryParameters, containsPair('DGHT_CRSE_SC_NM', '야간'));

      await client.classrooms(_seoulHigh, courseName: '고등학교', trackName: '일반계');
      expect(asked.queryParameters, containsPair('SCHUL_CRSE_SC_NM', '고등학교'));
      expect(asked.queryParameters, containsPair('ORD_SC_NM', '일반계'));
    });

    test('timetable sends period, classroom, and course filters', () async {
      await client.timetable(
        _seoulHigh,
        date: neisToday(),
        archived: false,
        period: 3,
        classroomName: '과학실',
        dayNightName: '주간',
        trackName: '일반계',
        departmentName: '일반학과',
        courseName: '고등학교',
      );

      expect(asked.queryParameters, containsPair('PERIO', '3'));
      expect(asked.queryParameters, containsPair('CLRM_NM', '과학실'));
      expect(asked.queryParameters, containsPair('DGHT_CRSE_SC_NM', '주간'));
      expect(asked.queryParameters, containsPair('ORD_SC_NM', '일반계'));
      expect(asked.queryParameters, containsPair('DDDEP_NM', '일반학과'));
      expect(asked.queryParameters, containsPair('SCHUL_CRSE_SC_NM', '고등학교'));
    });
  });

  group('new model fields', () {
    test('schools read postal code, fax, and founding date', () {
      final school = NeisSchool.fromRow(const {
        'ATPT_OFCDC_SC_CODE': 'B10',
        'SD_SCHUL_CODE': '7010057',
        'SCHUL_NM': '가락고등학교',
        'JU_ORG_NM': '서울특별시교육청',
        'ORG_RDNZC': '05678 ',
        'ORG_RDNDA': '(송파동,가락고등학교)',
        'ORG_FAXNO': '02-421-9669',
        'COEDU_SC_NM': '남여공학',
        'HS_SC_NM': '일반고',
        'DGHT_SC_NM': '주간',
        'FOND_YMD': '19881223',
      });

      expect(school.postalCode, '05678');
      expect(school.addressDetail, '(송파동,가락고등학교)');
      expect(school.fax, '02-421-9669');
      expect(school.coeducation, '남여공학');
      expect(school.highSchoolKind, '일반고');
      expect(school.dayNight, '주간');
      expect(school.foundedOn, DateTime(1988, 12, 23));
      expect(school.supervisor, '서울특별시교육청');
      expect(const NeisSchool.codes('B10', '1').postalCode, isNull);
    });

    test('schedule events read grades, year, and course', () {
      final event = NeisScheduleEvent.fromRow(const {
        'AY': '2026',
        'AA_YMD': '20260902',
        'DGHT_CRSE_SC_NM': '주간',
        'SCHUL_CRSE_SC_NM': '고등학교',
        'EVENT_NM': '전국연합학력평가(1,2)',
        'ONE_GRADE_EVENT_YN': 'Y',
        'TW_GRADE_EVENT_YN': 'Y',
        'THREE_GRADE_EVENT_YN': 'N',
        'FR_GRADE_EVENT_YN': '*',
        'FIV_GRADE_EVENT_YN': '*',
        'SIX_GRADE_EVENT_YN': '*',
        'SBTR_DD_SC_NM': '해당없음',
      });

      expect(event.grades, [1, 2]);
      expect(event.appliesToGrade(1), isTrue);
      expect(event.appliesToGrade(3), isFalse);
      expect(event.year, '2026');
      expect(event.courseName, '고등학교');
      expect(event.dayNightName, '주간');
      expect(event.isSaturdayBreak, isFalse);
      expect(
        NeisScheduleEvent(date: DateTime(2026), name: '개학').appliesToGrade(4),
        isTrue,
      );
    });

    test('lessons read semester, classroom, and department', () {
      final lesson = NeisLesson.fromRow(const {
        'AY': '2026',
        'SEM': '2',
        'ALL_TI_YMD': '20261014',
        'DGHT_CRSE_SC_NM': '주간',
        'ORD_SC_NM': '일반계',
        'DDDEP_NM': '일반학과',
        'GRADE': '1',
        'CLRM_NM': '1',
        'CLASS_NM': '1',
        'PERIO': '1',
        'ITRT_CNTNT': '체육2',
      });

      expect(lesson.year, '2026');
      expect(lesson.semester, '2');
      expect(lesson.classroomName, '1');
      expect(lesson.trackName, '일반계');
      expect(lesson.departmentName, '일반학과');
      expect(lesson.dayNightName, '주간');
    });

    test('classes read track and day or night', () {
      final group = NeisClass.fromRow(const {
        'AY': '2026',
        'GRADE': '1',
        'CLASS_NM': '1',
        'DGHT_CRSE_SC_NM': '주간',
        'ORD_SC_NM': '일반계',
      });

      expect(group.dayNightName, '주간');
      expect(group.trackName, '일반계');
    });

    test('academies read registration, suspension, and capacity', () {
      final open = NeisAcademy.fromRow(const {
        'ACA_NM': '301아카데미(Academy)영어교습소',
        'ACA_ASNUM': '3000040501',
        'REG_YMD': '20211228',
        'CAA_BEGIN_YMD': '        ',
        'CAA_END_YMD': '99991231',
        'DTM_RCPTN_ABLTY_NMPR_SMTOT': 9,
        'THCC_OTHBC_YN': 'Y',
        'BRHS_ACA_YN': 'N',
        'FA_RDNDA': ', 3층 301호 (개포동, 삼성빌딩)',
        'FA_RDNZC': '06329',
      });

      expect(open.registeredOn, DateTime(2021, 12, 28));
      expect(open.suspendedFrom, isNull);
      expect(open.suspendedUntil, isNull);
      expect(open.simultaneousCapacity, 9);
      expect(open.tuitionDisclosed, isTrue);
      expect(open.isBranch, isFalse);
      expect(open.addressDetail, '3층 301호 (개포동, 삼성빌딩)');
      expect(open.postalCode, '06329');

      final suspended = NeisAcademy.fromRow(const {
        'ACA_NM': '휴원학원',
        'ACA_ASNUM': '1',
        'CAA_BEGIN_YMD': '20260301',
        'CAA_END_YMD': '20260831',
        'BRHS_ACA_YN': '',
      });
      expect(suspended.suspendedFrom, DateTime(2026, 3, 1));
      expect(suspended.suspendedUntil, DateTime(2026, 8, 31));
      expect(suspended.isBranch, isNull);
    });
  });

  group('iCalendar export', () {
    final stamp = DateTime.utc(2026, 10, 22, 1, 2, 3);
    const school = <String, Object?>{
      'ATPT_OFCDC_SC_CODE': 'B10',
      'SD_SCHUL_CODE': '7010083',
    };
    final events = [
      NeisScheduleEvent(
        date: DateTime(2026, 10, 9),
        name: '한글날',
        dayKind: '공휴일',
        grades: const [1, 2, 3],
        raw: school,
      ),
      NeisScheduleEvent(
        date: DateTime(2026, 10, 10),
        name: '토요휴업일',
        dayKind: '휴업일',
        raw: school,
      ),
      NeisScheduleEvent(
        date: DateTime(2026, 12, 31),
        name: '종업식, 방학식; 정리',
        content: '첫째 줄\n둘째 줄 \\ 끝',
        dayKind: '해당없음',
        grades: const [2],
        raw: school,
      ),
    ];

    test('writes an RFC 5545 calendar', () {
      final ics = events.toIcs(name: '서울고등학교', stamp: stamp);

      expect(ics, startsWith('BEGIN:VCALENDAR\r\nVERSION:2.0\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
      expect(ics, contains('X-WR-CALNAME:서울고등학교\r\n'));
      expect(ics, contains('DTSTAMP:20261022T010203Z\r\n'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261009\r\n'));
      expect(ics, contains('DTEND;VALUE=DATE:20261010\r\n'));
      expect(ics, contains('DTEND;VALUE=DATE:20270101\r\n'));
      expect(ics, contains('CATEGORIES:공휴일\r\n'));
      expect(ics, contains(r'SUMMARY:종업식\, 방학식\; 정리'));
      expect(ics, contains(r'DESCRIPTION:첫째 줄\n둘째 줄 \\ 끝'));
      expect('BEGIN:VEVENT'.allMatches(ics), hasLength(2));
      expect(ics, isNot(contains('토요휴업일')));
    });

    test('keeps Saturday breaks on request and filters by grade', () {
      final all = events.toIcs(includeSaturdayBreaks: true, stamp: stamp);
      final third = events.toIcs(grade: 3, stamp: stamp);

      expect('BEGIN:VEVENT'.allMatches(all), hasLength(3));
      expect('BEGIN:VEVENT'.allMatches(third), hasLength(1));
      expect(third, contains('한글날'));
    });

    test('gives stable UIDs and drops repeated events', () {
      final first = events.toIcs(stamp: stamp);
      final again = [...events, events.first].toIcs(stamp: stamp);
      final uids = RegExp(r'UID:(.*)\r\n').allMatches(first).map((m) => m[1]);

      expect(uids.first, startsWith('20261009-B10-7010083-'));
      expect(uids.first, endsWith('@neis-plus'));
      expect(again, first);
    });

    test('folds long lines at 75 octets without splitting characters', () {
      final long = [
        NeisScheduleEvent(
          date: DateTime(2026, 11, 19),
          name: '대학수학능력시험 ' * 8,
          raw: school,
        ),
      ].toIcs(stamp: stamp);

      final lines = long.split('\r\n');
      expect(lines.where((line) => line.startsWith(' ')), isNotEmpty);
      for (final line in lines) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      // Unfolding gives back the original line.
      expect(
        long.replaceAll('\r\n ', ''),
        contains('SUMMARY:${('대학수학능력시험 ' * 8).trim()}'),
      );
    });
  });

  test('NeisErrorCode lists every code the client maps to', () {
    for (final code in [
      'ERROR-290',
      'INFO-300',
      'ERROR-300',
      'ERROR-333',
      'ERROR-310',
      'ERROR-336',
      'ERROR-337',
      'ERROR-500',
      'ERROR-999',
    ]) {
      expect(NeisErrorCode.all, contains(neisErrorCodeFor(code)));
    }
    expect(NeisErrorCode.all.toSet(), hasLength(NeisErrorCode.all.length));
  });
}
