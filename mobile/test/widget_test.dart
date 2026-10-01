import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

void main() {
  testWidgets('app shows the splash screen and continues to sign in', (tester) async {
    await tester.pumpWidget(const TaskInspectApp());

    expect(find.text('TaskInspect'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
  });
}
