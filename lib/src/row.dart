import 'models.dart' show parseNeisDate;

/// One row of a NEIS response, for services this package has no model for.
///
/// NEIS sends every field as a string, including numbers and `yyyyMMdd`
/// dates, so this wrapper reads them back out:
///
/// ```dart
/// final rows = await neis.call(NeisService.acaInsTiInfo, {
///   'ATPT_OFCDC_SC_CODE': 'B10',
/// });
/// for (final row in rows) {
///   print('${row.text('ACA_NM')} ${row.date('ESTBL_YMD')}');
/// }
/// ```
class NeisRow {
  /// Wraps [fields] as they arrived.
  const NeisRow(this.fields);

  /// The row exactly as NEIS sent it.
  final Map<String, Object?> fields;

  /// Reads [field] without interpreting it.
  Object? operator [](String field) => fields[field];

  /// Whether NEIS sent [field] at all.
  bool has(String field) => fields.containsKey(field);

  /// Reads [field] as text, treating a blank value as missing.
  String? text(String field) {
    final value = fields[field];
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// Reads [field] as a whole number, or `null` when it is not one.
  int? integer(String field) => int.tryParse(text(field) ?? '');

  /// Reads [field] as a number, or `null` when it is not one.
  double? number(String field) => double.tryParse(text(field) ?? '');

  /// Reads [field] as a `yyyyMMdd` date, or `null` when it is not one.
  DateTime? date(String field) => parseNeisDate(text(field) ?? '');

  /// A copy of [fields].
  Map<String, Object?> toMap() => Map<String, Object?>.of(fields);

  @override
  String toString() => 'NeisRow(${fields.length} fields)';
}
