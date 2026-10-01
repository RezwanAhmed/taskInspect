import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/router/app_router.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  setUp(() => registerFakeTasks(FakeTaskRepository()));
  testWidgets('logged-out users cannot open the tasks screen', (tester) async {
    await tester.pumpWidget(TaskInspectApp(
      authBloc: authBlocWith(FakeAuthRepository()),
      initialLocation: AppRoutes.home,
    ));
    await tester.pumpAndSettle();

    expect(find.text('to TaskInspect'), findsOneWidget);
  });

  testWidgets('unknown route shows page not found with a way back', (tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(Scaffold))).go('/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
  });
}
