import 'package:taskinspect/core/error/failure.dart';

/// The outcome of an operation that can fail: either [Ok] with a value or
/// [Err] with a [Failure]. Use cases and repositories return this instead
/// of throwing, so every caller has to handle the failure case.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
