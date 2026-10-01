import 'package:taskinspect/core/error/failure.dart';

/// Turns a [Failure] into a message the user understands (spec section 23).
String userMessage(Failure failure) {
  return switch (failure) {
    NetworkFailure() => "Changes saved locally. They will sync when you're online.",
    UnauthorizedFailure(code: 'INVALID_CREDENTIALS', :final message) => message ?? 'Email or password is incorrect',
    UnauthorizedFailure() => 'Your session has expired. Please sign in again.',
    ServerFailure(isServerError: true) => 'Unable to synchronize. Please try again.',
    ServerFailure(:final message?) => message,
    ServerFailure() => 'Something went wrong. Please try again.',
    UnexpectedFailure() => 'Something went wrong. Please try again.',
  };
}
