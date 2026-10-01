/// What went wrong, in terms the app can act on. The data layer turns every
/// exception (network, server, database) into one of these.
sealed class Failure {
  const Failure();
}

/// No connection, or the server could not be reached in time.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The request needs a (valid) login: missing, invalid or expired token,
/// or wrong credentials. [code] is the backend error code, if any.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({this.code, this.message});

  final String? code;
  final String? message;
}

/// The server answered with an error, e.g. `409 TASK_INVALID_TRANSITION` or
/// `400 VALIDATION_ERROR` (then [fieldErrors] says which fields are wrong).
final class ServerFailure extends Failure {
  const ServerFailure({
    required this.statusCode,
    this.code,
    this.message,
    this.requestId,
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String? code;
  final String? message;

  /// Shown in error reports so the matching server log can be found.
  final String? requestId;

  /// Field name -> problem, for `VALIDATION_ERROR`.
  final Map<String, String> fieldErrors;

  bool get isServerError => statusCode >= 500;
}

/// A bug or an answer the app could not understand.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(this.error);

  final Object error;
}
