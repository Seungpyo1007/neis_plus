/// A failed call to the NEIS open API.
class NeisException implements Exception {
  /// Creates a failure.
  const NeisException(this.message, {required this.code, this.resultCode});

  /// Safe error description, including the portal's own message when it sends
  /// one. The API key is never included.
  final String message;

  /// Stable error code, one of the [NeisErrorCode] constants:
  /// `invalid_key`, `key_disabled`, `missing_parameter`,
  /// `invalid_parameter`, `unknown_service`, `too_many_rows`, `rate_limit`,
  /// `server_error`, `service_error`, `http_error`, `timeout`, or
  /// `invalid_response`.
  ///
  /// ```dart
  /// on NeisException catch (e) {
  ///   if (e.code == NeisErrorCode.rateLimit) await backOff();
  /// }
  /// ```
  final String code;

  /// The portal's own result code, such as `ERROR-290`, when it sends one.
  final String? resultCode;

  @override
  String toString() => message;
}

/// The values [NeisException.code] takes, so a caller can compare against a
/// constant instead of spelling the string.
abstract final class NeisErrorCode {
  /// `ERROR-290`: the API key is not registered.
  static const invalidKey = 'invalid_key';

  /// `INFO-300`: the API key was disabled.
  static const keyDisabled = 'key_disabled';

  /// `ERROR-300`, or a required parameter this package checks before
  /// sending, such as a school without codes.
  static const missingParameter = 'missing_parameter';

  /// `ERROR-333` to `ERROR-335`: a parameter has the wrong type or range.
  static const invalidParameter = 'invalid_parameter';

  /// `ERROR-310`: no service has that name.
  static const unknownService = 'unknown_service';

  /// `ERROR-336`: more than 1000 rows asked for in one page.
  static const tooManyRows = 'too_many_rows';

  /// `ERROR-337`: the daily request limit was reached.
  static const rateLimit = 'rate_limit';

  /// `ERROR-500`, `ERROR-600`, `ERROR-601`: NEIS failed on its side.
  static const serverError = 'server_error';

  /// Any other result code NEIS sent.
  static const serviceError = 'service_error';

  /// The request did not reach NEIS or the connection failed.
  static const httpError = 'http_error';

  /// No answer within the client's timeout, after one retry.
  static const timeout = 'timeout';

  /// NEIS answered with something that is not the usual JSON.
  static const invalidResponse = 'invalid_response';

  /// Every code, in the order above.
  static const all = <String>[
    invalidKey,
    keyDisabled,
    missingParameter,
    invalidParameter,
    unknownService,
    tooManyRows,
    rateLimit,
    serverError,
    serviceError,
    httpError,
    timeout,
    invalidResponse,
  ];
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
