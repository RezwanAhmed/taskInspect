import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taskinspect/core/synchronization/background_sync_registration.dart';
import 'package:workmanager/workmanager.dart';

class _MockWorkmanager extends Mock implements Workmanager {}

void _dispatcher() {}

void main() {
  late _MockWorkmanager workmanager;

  setUpAll(() {
    registerFallbackValue(Constraints());
    registerFallbackValue(ExistingPeriodicWorkPolicy.update);
    registerFallbackValue(BackoffPolicy.exponential);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    workmanager = _MockWorkmanager();
    when(() => workmanager.initialize(_dispatcher)).thenAnswer((_) async {});
    when(() => workmanager.registerPeriodicTask(
          any(),
          any(),
          frequency: any(named: 'frequency'),
          constraints: any(named: 'constraints'),
          existingWorkPolicy: any(named: 'existingWorkPolicy'),
          backoffPolicy: any(named: 'backoffPolicy'),
          backoffPolicyDelay: any(named: 'backoffPolicyDelay'),
        )).thenAnswer((_) async {});
    when(() => workmanager.cancelByUniqueName(any())).thenAnswer((_) async {});
  });

  test('schedules one periodic sync every 15 minutes while online', () async {
    final registration = WorkmanagerSyncRegistration(workmanager: workmanager, isSupported: true);

    await registration.initialize(_dispatcher);
    await registration.schedule();

    verify(() => workmanager.initialize(_dispatcher)).called(1);
    final constraints = verify(() => workmanager.registerPeriodicTask(
          WorkmanagerSyncRegistration.uniqueName,
          WorkmanagerSyncRegistration.uniqueName,
          frequency: const Duration(minutes: 15),
          constraints: captureAny(named: 'constraints'),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
          backoffPolicy: BackoffPolicy.exponential,
          backoffPolicyDelay: const Duration(seconds: 30),
        )).captured.single as Constraints;
    expect(constraints.networkType, NetworkType.connected);
  });

  test('cancel removes the periodic sync', () async {
    await WorkmanagerSyncRegistration(workmanager: workmanager, isSupported: true).cancel();

    verify(() => workmanager.cancelByUniqueName(WorkmanagerSyncRegistration.uniqueName)).called(1);
  });

  test('does nothing where background sync is not set up yet (iOS until task 12.7)', () async {
    final registration = WorkmanagerSyncRegistration(workmanager: workmanager, isSupported: false);

    await registration.initialize(_dispatcher);
    await registration.schedule();
    await registration.cancel();

    verifyZeroInteractions(workmanager);
  });
}
