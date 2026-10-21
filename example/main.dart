import 'dart:io';

import 'package:neis_plus/neis_plus.dart';

/// Prints today's meal and timetable for a school:
///
///     dart run example/main.dart 서울고
///
/// Set NEIS_KEY to use your own API key; without one NEIS still answers a
/// limited number of requests.
Future<void> main(List<String> args) async {
  final name = args.isEmpty ? '서울고' : args.first;
  final client = NeisClient(apiKey: Platform.environment['NEIS_KEY']);

  try {
    final school = await client.findSchool(name);
    if (school == null) {
      print('"$name" 학교를 찾지 못했습니다.');
      return;
    }
    print('${school.name} (${school.region}, ${school.kind.label})');

    final today = neisToday();
    final meals = await client.todayMeals(school);
    if (meals.isEmpty) {
      print('  오늘 급식 정보가 없습니다.');
    }
    for (final meal in meals) {
      print('  ${meal.typeName} (${meal.kcal ?? '-'} kcal)');
      for (final dish in meal.dishes) {
        final allergens = dish.allergenNames;
        print(
          '    - ${dish.cleanName}'
          '${allergens.isEmpty ? '' : ' [${allergens.join(', ')}]'}',
        );
      }
      if (meal.nutrition['단백질'] case final protein?) {
        print('    단백질 ${protein.value}${protein.unit ?? ''}');
      }
    }

    // Without CLASS_NM the API returns every class of the grade, so ask for
    // one class.
    final lessons = await client.timetable(
      school,
      date: today,
      grade: '1',
      className: '1',
    );
    if (lessons.isNotEmpty) {
      print('  1학년 1반 시간표');
      for (final lesson in lessons) {
        print('    ${lesson.period}교시 ${lesson.subject}');
      }
    }
  } on NeisException catch (error) {
    print('${error.code}: $error');
  } finally {
    client.close();
  }
}
