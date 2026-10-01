import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskinspect/main.dart' as app;

/// End to end on a device or emulator against a running backend:
///
/// ```
/// flutter test integration_test/login_test.dart \
///   --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
/// ```
///
/// Skipped when no credentials are given (e.g. in CI without a backend).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const email = String.fromEnvironment('E2E_EMAIL');
  const password = String.fromEnvironment('E2E_PASSWORD');

  testWidgets(
    'signs in against the real backend',
    (tester) async {
      await app.main();
      // A fresh install has no saved session.
      await _pumpUntil(tester, find.text('to TaskInspect'));
      expect(find.text('to TaskInspect'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login-email')), 'wrong@example.com');
      await tester.enterText(find.byKey(const Key('login-password')), 'wrong-password');
      await tester.tap(find.byKey(const Key('login-submit')));
      await _pumpUntil(tester, find.byKey(const Key('login-error')));
      expect(find.text('Email or password is incorrect'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login-email')), email);
      await tester.enterText(find.byKey(const Key('login-password')), password);
      await tester.tap(find.byKey(const Key('login-submit')));
      await _pumpUntil(tester, find.textContaining('Hello, '));
      expect(find.textContaining('Hello, '), findsOneWidget);
    },
    skip: email.isEmpty || password.isEmpty,
  );
}

/// Waits for a real network answer (pumpAndSettle can't see HTTP calls).
Future<void> _pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}
