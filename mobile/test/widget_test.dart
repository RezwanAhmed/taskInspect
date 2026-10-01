import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

import 'helpers/fake_auth.dart';
import 'helpers/fake_tasks.dart';

void main() {
  setUp(() => registerFakeTasks(FakeTaskRepository()));
  testWidgets('without a saved session the app shows sign in', (tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('to TaskInspect'), findsOneWidget);
  });

  testWidgets('with a saved session the app opens the tasks screen', (tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
  });
}
