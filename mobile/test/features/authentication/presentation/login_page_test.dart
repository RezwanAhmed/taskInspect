import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/authentication/domain/entities/unsynced_changes.dart';

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

  testWidgets('offline sign in explains that a connection is needed; it works once online', (tester) async {
    final repository = FakeAuthRepository()..loginFailure = const NetworkFailure();
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(repository)));
    await tester.pumpAndSettle();

    await signIn(tester, 'worker@example.com', 'secret');

    expect(find.byKey(const Key('login-error')), findsOneWidget);
    expect(find.text('No internet connection. Connect to sign in.'), findsOneWidget);
    expect(find.text('Hello, Wendy Worker'), findsNothing);

    repository.loginFailure = null;
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Wendy Worker'), findsOneWidget);
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

  group('unsynced changes of another account on the device', () {
    const unsynced = UnsyncedChanges(ownerEmail: 'worker@example.com', count: 2);

    Future<FakeAuthRepository> openWithUnsynced(WidgetTester tester) async {
      final repository = FakeAuthRepository(unsynced: unsynced);
      await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(repository)));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('the login screen says whose changes they are', (tester) async {
      await openWithUnsynced(tester);

      expect(find.byKey(const Key('login-unsynced')), findsOneWidget);
      expect(find.text('2 changes not synced yet'), findsOneWidget);
      expect(find.textContaining('Sign in as worker@example.com to keep them'), findsOneWidget);
    });

    testWidgets('signing in as the owner keeps them, without asking', (tester) async {
      await openWithUnsynced(tester);

      await signIn(tester, ' worker@example.com', 'secret');

      expect(find.text('Delete unsynced changes?'), findsNothing);
      expect(find.text('Hello, Wendy Worker'), findsOneWidget);
    });

    testWidgets('another account asks first; Cancel does not sign in', (tester) async {
      final repository = await openWithUnsynced(tester);

      await signIn(tester, 'manager@example.com', 'secret');

      expect(find.text('Delete unsynced changes?'), findsOneWidget);
      expect(find.textContaining('2 changes of worker@example.com are not synced yet'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.savedUser, isNull);
      expect(find.byKey(const Key('login-unsynced')), findsOneWidget);
    });

    testWidgets('an unknown owner (older data) is "the previous user", and every account is asked', (tester) async {
      await tester.pumpWidget(TaskInspectApp(
        authBloc: authBlocWith(FakeAuthRepository(unsynced: const UnsyncedChanges(ownerEmail: null, count: 1))),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign in as the previous user to keep them'), findsOneWidget);

      await signIn(tester, 'worker@example.com', 'secret');

      expect(find.textContaining('1 change of the previous user is not synced yet'), findsOneWidget);
    });

    testWidgets('confirming signs in with the other account', (tester) async {
      await openWithUnsynced(tester);

      await signIn(tester, 'other@example.com', 'wrong');
      await tester.tap(find.text('Delete and sign in'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login-error')), findsOneWidget, reason: 'the sign in was sent (wrong password)');
    });
  });
}
