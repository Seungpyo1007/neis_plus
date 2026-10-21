/// Reads a NEIS field as a whole number, or returns `null`.
///
/// NEIS sends most numbers as strings, but a few, such as `MLSV_FGR`, as JSON
/// numbers like `780.00`. The Dart VM decodes those as doubles and the web as
/// whole numbers, so both shapes are accepted here, as are strings like
/// `"780.00"`. A value with a fractional part is not a whole number.
int? neisInt(Object? value) {
  if (value is int) return value;
  final number = value is num ? value.toDouble() : _parse(value);
  if (number == null || number != number.truncateToDouble()) return null;
  return number.toInt();
}

/// Reads a NEIS field as a number, or returns `null`.
double? neisDouble(Object? value) =>
    value is num ? value.toDouble() : _parse(value);

double? _parse(Object? value) {
  final number = double.tryParse('${value ?? ''}'.trim());
  return number != null && number.isFinite ? number : null;
}
