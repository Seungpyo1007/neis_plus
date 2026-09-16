/// A failed call to the NEIS open API.
class NeisException implements Exception {
  /// Creates a failure.
  const NeisException(this.message, {required this.code, this.resultCode});

  /// Safe error description, including the portal's own message when it sends
  /// one. The API key is never included.
  final String message;

  /// Stable error code: `invalid_key`, `key_disabled`, `missing_parameter`,
  /// `invalid_parameter`, `unknown_service`, `too_many_rows`, `rate_limit`,
  /// `server_error`, `service_error`, `http_error`, `timeout`, or
  /// `invalid_response`.
  final String code;

  /// The portal's own result code, such as `ERROR-290`, when it sends one.
  final String? resultCode;

  @override
  String toString() => message;
}

/// Maps a NEIS result code to a stable [NeisException.code].
String neisErrorCodeFor(String? resultCode) => switch (resultCode) {
  'ERROR-290' => 'invalid_key',
  'INFO-300' => 'key_disabled',
  'ERROR-300' => 'missing_parameter',
  'ERROR-333' || 'ERROR-334' || 'ERROR-335' => 'invalid_parameter',
  'ERROR-310' => 'unknown_service',
  'ERROR-336' => 'too_many_rows',
  'ERROR-337' => 'rate_limit',
  'ERROR-500' || 'ERROR-600' || 'ERROR-601' => 'server_error',
  _ => 'service_error',
};

/// Whether a result code means the query matched nothing, which this package
/// reports as an empty list instead of an error.
bool neisIsNoData(String? resultCode) => resultCode == 'INFO-200';

/// Whether a result code means the request succeeded.
bool neisIsOk(String? resultCode) => resultCode == 'INFO-000';
