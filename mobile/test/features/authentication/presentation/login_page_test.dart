import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

import '../../../helpers/fake_auth.dart';
import '../../../helpers/fake_tasks.dart';

void main() {
  setUp(() => registerFakeTasks(FakeTaskRepository()));
  Future<void> openLogin(WidgetTester tester) async {
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository())));
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('correct email and password open the app', (tester) async {
    await openLogin(tester);

    await signIn(tester, ' worker@example.com ', 'secret');

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
  });

  testWidgets('wrong password shows the error and stays on sign in', (tester) async {
    await openLogin(tester);

    await signIn(tester, 'worker@example.com', 'wrong');

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('Email or password is incorrect'), findsOneWidget);
  });

  testWidgets('empty email is shown under the email field', (tester) async {
    await openLogin(tester);

    await signIn(tester, '', 'secret');

    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.byKey(const Key('login-error')), findsNothing);
  });

  testWidgets('password can be shown and hidden', (tester) async {
    await openLogin(tester);
    TextField password() => tester.widget<TextField>(find.byKey(const Key('login-password')));

    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });
}
