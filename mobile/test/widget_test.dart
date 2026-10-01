import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';

void main() {
  testWidgets('app starts and shows its name', (tester) async {
    await tester.pumpWidget(const TaskInspectApp());

    expect(find.text('TaskInspect'), findsOneWidget);
  });
}
