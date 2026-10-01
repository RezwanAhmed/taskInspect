import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';

void main() {
  test('messages from the spec', () {
    expect(userMessage(const NetworkFailure()), "Changes saved locally. They will sync when you're online.");
    expect(userMessage(const ServerFailure(statusCode: 500)), 'Unable to synchronize. Please try again.');
    expect(userMessage(const UnauthorizedFailure(code: 'INVALID_TOKEN')),
        'Your session has expired. Please sign in again.');
  });

  test('wrong login keeps the backend message', () {
    expect(
      userMessage(const UnauthorizedFailure(code: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect')),
      'Email or password is incorrect',
    );
  });

  test('business errors show the backend message', () {
    expect(
      userMessage(const ServerFailure(statusCode: 409, code: 'TASK_ALREADY_APPROVED',
          message: 'Task has already been approved')),
      'Task has already been approved',
    );
    expect(userMessage(const ServerFailure(statusCode: 400)), 'Something went wrong. Please try again.');
  });
}
