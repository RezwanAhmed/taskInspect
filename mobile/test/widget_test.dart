import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

import 'helpers/fake_auth.dart';

void main() {
  testWidgets('without a saved session the app shows sign in', (tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('to TaskInspect'), findsOneWidget);
  });

  testWidgets('with a saved session the app opens the tasks screen', (tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();

    expect(find.text('Signed in as Wendy Worker'), findsOneWidget);
  });
}
