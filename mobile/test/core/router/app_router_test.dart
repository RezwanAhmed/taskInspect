import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/router/app_router.dart';

void main() {
  testWidgets('home route shows the tasks screen', (tester) async {
    await tester.pumpWidget(const TaskInspectApp(initialLocation: AppRoutes.home));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsOneWidget);
  });

  testWidgets('unknown route shows page not found with a way back', (tester) async {
    await tester.pumpWidget(const TaskInspectApp(initialLocation: '/does-not-exist'));
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });
}
