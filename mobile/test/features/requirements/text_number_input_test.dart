import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/number_input.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  test('number parsing', () {
    expect(NumberInput.parse('3.5'), 3.5);
    expect(NumberInput.parse('3,5'), 3.5);
    expect(NumberInput.parse(' -2 '), -2);
    expect(NumberInput.parse(''), isNull);
    expect(NumberInput.parse('abc'), isNull);
    expect(NumberInput.parse('NaN'), isNull);
  });

  Future<void> open(WidgetTester tester) async {
    registerFakeTasks(FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Record refrigerator temperature',
              type: RequirementType.number, required: true, position: 0, unit: '°C'),
          Requirement(id: 'r2', taskId: 't1', title: 'Notes', type: RequirementType.text, required: true, position: 1),
        ],
      });
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('number shows the unit and accepts a decimal comma', (tester) async {
    await open(tester);

    expect(find.text('°C'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('number-input')), '3,5');
    await tester.pump();

    expect(find.textContaining('1 answered'), findsOneWidget);
  });

  testWidgets('something that is not a number is flagged and not counted', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('number-input')), 'cold');
    await tester.pump();

    expect(find.text('Enter a number'), findsOneWidget);
    expect(find.textContaining('0 answered'), findsOneWidget);
  });

  testWidgets('text answers count once they have content and are kept between pages', (tester) async {
    await open(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('text-input')), '   ');
    await tester.pump();
    expect(find.textContaining('0 answered'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('text-input')), 'Door seal is worn');
    await tester.pump();
    expect(find.textContaining('1 answered'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Door seal is worn'), findsOneWidget);
  });
}
