import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/synchronization/sync_status.dart';
import 'package:taskinspect/core/synchronization/sync_status_cubit.dart';
import 'package:taskinspect/shared/widgets/sync_status_banner.dart';

import '../helpers/fake_tasks.dart';

void main() {
  late FakeSyncStatusSource source;

  Future<void> show(WidgetTester tester, SyncStatus status) async {
    source = FakeSyncStatusSource(status);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (_) => SyncStatusCubit(source, () async => source.retries++)..start(),
          child: const SyncStatusBanner(),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('nothing when everything is on the server', (tester) async {
    await show(tester, const SyncStatus());

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('offline: changes are saved locally, with the number waiting', (tester) async {
    await show(tester, const SyncStatus(online: false, unsent: 3));

    expect(find.byKey(const Key('sync-offline')), findsOneWidget);
    expect(find.text("Changes saved locally. They will sync when you're online."), findsOneWidget);
    expect(find.text('3 changes waiting.'), findsOneWidget);
  });

  testWidgets('failed: data is safe, the reason, and Retry', (tester) async {
    await show(tester, const SyncStatus(unsent: 1, failed: 1, failureCode: 'TASK_INVALID_TRANSITION'));

    expect(find.text('Unable to synchronize. Your changes are saved on this device.'), findsOneWidget);
    expect(find.text('The task was changed on the server, for example cancelled by the manager.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(source.retries, 1);
  });

  testWidgets('a temporary failure has no extra reason', (tester) async {
    await show(tester, const SyncStatus(unsent: 1, failed: 1, failureCode: 'NETWORK_ERROR'));

    expect(find.byKey(const Key('sync-failed')), findsOneWidget);
    expect(SyncStatusBanner.reason('NETWORK_ERROR'), isNull);
    expect(SyncStatusBanner.reason('SOMETHING_NEW'), 'The server refused a change (SOMETHING_NEW).');
  });

  testWidgets('syncing shows progress, then changes waiting, then nothing', (tester) async {
    await show(tester, const SyncStatus(syncing: true, unsent: 2));
    expect(find.byKey(const Key('sync-progress')), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    source.emit(const SyncStatus(unsent: 1));
    await tester.pump();
    expect(find.text('1 change waiting to sync.'), findsOneWidget);

    source.emit(const SyncStatus());
    await tester.pump();
    expect(find.byType(Card), findsNothing);
  });
}
