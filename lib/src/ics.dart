import 'dart:convert';

import 'models.dart';

/// Exports a school calendar as an iCalendar (`.ics`) file.
///
/// ```dart
/// final events = await neis.schedule(school, from: start, to: end);
/// File('calendar.ics').writeAsStringSync(events.toIcs(name: school.name));
/// ```
extension NeisScheduleIcs on Iterable<NeisScheduleEvent> {
  /// The events as an iCalendar document (RFC 5545), one all-day event per
  /// entry.
  ///
  /// [grade] keeps only the events for that grade (see
  /// [NeisScheduleEvent.appliesToGrade]). The weekly 토요휴업일 entries are
  /// left out unless [includeSaturdayBreaks] is true. [name] becomes the
  /// calendar name. [stamp] sets `DTSTAMP`, the current time by default; pass
  /// a fixed value for reproducible output.
  ///
  /// Each event gets a stable `UID` built from the school, the date, and the
  /// event name, so importing an updated export replaces events instead of
  /// duplicating them.
  String toIcs({
    String? name,
    int? grade,
    bool includeSaturdayBreaks = false,
    DateTime? stamp,
  }) {
    final dtStamp = _utcStamp(stamp ?? DateTime.now());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//neis_plus//NEIS school calendar//KO',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      if (name != null && name.trim().isNotEmpty)
        'X-WR-CALNAME:${_escape(name.trim())}',
    ];
    final seen = <String>{};
    for (final event in this) {
      if (event.date.year == 0) continue;
      if (!includeSaturdayBreaks && event.isSaturdayBreak) continue;
      if (grade != null && !event.appliesToGrade(grade)) continue;
      final uid = _uid(event);
      // NEIS repeats an event once per course of a combined school; keep one.
      if (!seen.add(uid)) continue;
      final start = DateTime(event.date.year, event.date.month, event.date.day);
      final end = DateTime(start.year, start.month, start.day + 1);
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:$uid',
        'DTSTAMP:$dtStamp',
        'DTSTART;VALUE=DATE:${_date(start)}',
        'DTEND;VALUE=DATE:${_date(end)}',
        'SUMMARY:${_escape(event.name.trim())}',
        if (event.content case final content? when content.trim().isNotEmpty)
          'DESCRIPTION:${_escape(content.trim())}',
        if (event.dayKind case final kind? when kind != '해당없음')
          'CATEGORIES:${_escape(kind)}',
        'TRANSP:TRANSPARENT',
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    return '${lines.map(_fold).join('\r\n')}\r\n';
  }
}

String _uid(NeisScheduleEvent event) {
  final school = [
    event.raw['ATPT_OFCDC_SC_CODE'],
    event.raw['SD_SCHUL_CODE'],
  ].map((value) => '${value ?? ''}'.trim()).join('-');
  // FNV-1a over the name keeps the UID short and ASCII.
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(event.name.trim())) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  final key = [
    _date(event.date),
    if (school != '-') school,
    hash.toRadixString(16).padLeft(8, '0'),
  ].join('-');
  return '$key@neis-plus';
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

String _utcStamp(DateTime time) {
  final utc = time.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${_date(utc)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

/// Escapes a TEXT value: backslash, semicolon, comma, and line breaks.
String _escape(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n');

/// Folds a content line to at most 75 octets per physical line, never
/// splitting a UTF-8 character.
String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final out = StringBuffer();
  var octets = 0;
  var limit = 75;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final size = utf8.encode(char).length;
    if (octets + size > limit) {
      out.write('\r\n ');
      octets = 0;
      // Continuation lines start with a space, which counts toward the 75.
      limit = 74;
    }
    out.write(char);
    octets += size;
  }
  return out.toString();
}
