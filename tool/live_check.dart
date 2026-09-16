// Checks the new 0.0.3 surface against the live NEIS API.
//
//     dart run tool/live_check.dart
import 'dart:io';

import 'package:neis_plus/neis_plus.dart';

Future<void> main() async {
  final neis = NeisClient(apiKey: Platform.environment['NEIS_KEY']);
  final garak = NeisSchool.codes('B10', '7010057', kind: NeisSchoolKind.high);
  var failures = 0;

  Future<void> check(String label, Future<Object?> Function() run) async {
    try {
      final value = await run();
      final ok = value != null && (value is! Iterable || value.isNotEmpty);
      if (!ok) failures++;
      print('${ok ? 'ok  ' : 'FAIL'} $label -> $value');
    } on Object catch (error) {
      failures++;
      print('FAIL $label -> $error');
    }
  }

  await check('academies B10 수학', () async {
    final rows = await neis.academies(
      officeCode: NeisOffice.seoul.code,
      name: '수학',
      maxPages: 1,
    );
    return '${rows.length} rows, first ${(rows.isEmpty ? '-' : rows.first.name)}';
  });

  await check('majors B10', () async {
    final rows = await neis.majors(
      officeCode: NeisOffice.seoul.code,
      maxPages: 1,
    );
    return '${rows.length} rows, first ${(rows.isEmpty ? '-' : rows.first.name)}';
  });

  await check('tracks B10', () async {
    final rows = await neis.tracks(
      officeCode: NeisOffice.seoul.code,
      maxPages: 1,
    );
    return '${rows.length} rows, first ${(rows.isEmpty ? '-' : rows.first.name)}';
  });

  await check('classrooms 가락고', () async {
    final rows = await neis.classrooms(garak, maxPages: 1);
    return '${rows.length} rows, first ${(rows.isEmpty ? '-' : rows.first.name)}';
  });

  await check('timetable archive 2023', () async {
    final rows = await neis.timetable(
      garak,
      year: '2023',
      grade: '1',
      className: '01', // the archive zero-pads class names
      archived: true,
      maxPages: 1,
    );
    return '${rows.length} lessons, first ${(rows.isEmpty ? '-' : rows.first.subject)}';
  });

  await check('timetable current 2023 is empty', () async {
    final rows = await neis.timetable(
      garak,
      year: '2023',
      archived: false,
      maxPages: 1,
    );
    return rows.isEmpty ? 'empty as expected' : null;
  });

  await check('call() on a service with no method', () async {
    final rows = await neis.call(NeisService.schulAflcoInfo, {
      'ATPT_OFCDC_SC_CODE': 'B10',
    }, maxPages: 1);
    return '${rows.length} rows, first ${(rows.isEmpty ? '-' : rows.first.text('ORD_SC_NM'))}';
  });

  await check('keyless call returns the 5-row cap in one request', () async {
    final rows = await NeisClient().schools(name: '고등학교', maxPages: 3);
    return rows.length == 5
        ? '${rows.length} schools (NEIS caps keyless calls)'
        : null;
  });

  await check('missing required parameter is caught locally', () async {
    try {
      await neis.call(NeisService.tiClrmInfo, {'ATPT_OFCDC_SC_CODE': 'B10'});
      return null;
    } on NeisException catch (error) {
      return error.code == 'missing_parameter' ? '$error' : null;
    }
  });

  neis.close();
  print(failures == 0 ? '\nall checks passed' : '\n$failures check(s) failed');
  exitCode = failures == 0 ? 0 : 1;
}
