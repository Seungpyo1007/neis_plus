/// Rows read from a NEIS service, with how many the service has.
///
/// The list methods stop after `maxPages` pages, 500 rows with the defaults,
/// without saying so. The `*Page` methods return this instead, so a caller can
/// tell a complete answer from a cut-off one:
///
/// ```dart
/// final page = await neis.academiesPage(officeCode: NeisOffice.seoul.code);
/// if (page.truncated) print('${page.items.length} of ${page.total}');
/// ```
class NeisPage<T> {
  /// Creates a page.
  const NeisPage(this.items, {required this.total, required this.truncated});

  /// The rows read.
  final List<T> items;

  /// Rows the service reports for the query, from `list_total_count`.
  ///
  /// NEIS sometimes reports more rows than it returns, so [items] can be
  /// complete while shorter than this.
  final int total;

  /// Whether reading stopped at `maxPages` while the service still had rows,
  /// or, without an API key, at the 5 rows NEIS sends keyless callers.
  final bool truncated;

  /// The same page with every item converted by [convert].
  ///
  /// ```dart
  /// final page = await neis.rawPage('acaInsTiInfo', {
  ///   'ATPT_OFCDC_SC_CODE': 'B10',
  /// });
  /// final academies = page.map(NeisAcademy.fromRow);
  /// ```
  NeisPage<R> map<R>(R Function(T item) convert) => NeisPage<R>(
    [for (final item in items) convert(item)],
    total: total,
    truncated: truncated,
  );

  @override
  String toString() =>
      'NeisPage(${items.length} of $total${truncated ? ', truncated' : ''})';
}
