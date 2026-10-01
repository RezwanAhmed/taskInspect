import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  setUp(() => registerFakeTasks(FakeTaskRepository()));
  Future<FakeAuthRepository> openSignedIn(WidgetTester tester) async {
    final repository = FakeAuthRepository(savedUser: testWorker);
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(repository)));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('signing out asks first and then returns to sign in', (tester) async {
    final repository = await openSignedIn(tester);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('to TaskInspect'), findsOneWidget);
    expect(repository.logouts, 1);
    expect(repository.savedUser, isNull);
  });

  testWidgets('cancel keeps the user signed in', (tester) async {
    final repository = await openSignedIn(tester);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
    expect(repository.logouts, 0);
  });
}
