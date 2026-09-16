import 'dart:io';

import 'package:neis_plus/neis_plus.dart';

/// Prints today's meal and timetable for a school:
///
///     dart run example/main.dart 서울고등학교
///
/// Set NEIS_KEY to use your own API key; without one NEIS still answers a
/// limited number of requests.
Future<void> main(List<String> args) async {
  final name = args.isEmpty ? '서울고등학교' : args.first;
  final client = NeisClient(apiKey: Platform.environment['NEIS_KEY']);

  try {
    final schools = await client.schools(name: name);
    if (schools.isEmpty) {
      print('"$name" 학교를 찾지 못했습니다.');
      return;
    }
    final school = schools.first;
    print('${school.name} (${school.region}, ${school.kind.label})');

    final today = DateTime.now();
    final meals = await client.meals(school, date: today);
    if (meals.isEmpty) {
      print('  오늘 급식 정보가 없습니다.');
    }
    for (final meal in meals) {
      print('  ${meal.typeName} (${meal.calories ?? '-'})');
      for (final dish in meal.dishes) {
        final allergens = dish.allergenNames;
        print(
          '    - ${dish.name}'
          '${allergens.isEmpty ? '' : ' [${allergens.join(', ')}]'}',
        );
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
