import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/di/injection.dart';

class _FakeService {}

void main() {
  test('configureDependencies starts from a clean container', () async {
    getIt.registerSingleton<_FakeService>(_FakeService());

    await configureDependencies();

    expect(getIt.isRegistered<_FakeService>(), isFalse);
  });

  test('can be called more than once', () async {
    await configureDependencies();
    await configureDependencies();
  });
}
