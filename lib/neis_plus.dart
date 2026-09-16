/// NEIS+ reads Korean school data from the NEIS open API
/// (`open.neis.go.kr`): schools, meals, timetables, calendars, classes,
/// departments, classrooms, and academies.
///
/// [NeisClient] has a method for every service NEIS publishes, and
/// [NeisService] names them all for [NeisClient.call].
library;

export 'src/client.dart';
export 'src/exception.dart';
export 'src/models.dart';
export 'src/row.dart';
export 'src/services.dart';
