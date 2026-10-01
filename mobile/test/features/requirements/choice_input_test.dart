import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  Future<void> open(WidgetTester tester) async {
    registerFakeTasks(FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
      ..requirements = {
        't1': const [
          Requirement(id: 'r1', taskId: 't1', title: 'Floor condition', type: RequirementType.dropdown,
              required: true, position: 0, options: [
                RequirementOption(id: 'clean', label: 'Clean', position: 0),
                RequirementOption(id: 'dirty', label: 'Needs cleaning', position: 1),
              ]),
          Requirement(id: 'r2', taskId: 't1', title: 'Problems found', type: RequirementType.multipleSelection,
              required: true, position: 1, options: [
                RequirementOption(id: 'leak', label: 'Leak', position: 0),
                RequirementOption(id: 'smell', label: 'Smell', position: 1),
                RequirementOption(id: 'noise', label: 'Noise', position: 2),
              ]),
        ],
      });
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  bool checked(WidgetTester tester, String id) =>
      tester.widget<CheckboxListTile>(find.byKey(Key('option-$id'))).value ?? false;

  testWidgets('dropdown: one option, changing the choice replaces it', (tester) async {
    await open(tester);

    expect(find.textContaining('0 answered'), findsOneWidget);
    await tester.tap(find.text('Clean'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 answered'), findsOneWidget);

    await tester.tap(find.text('Needs cleaning'));
    await tester.pumpAndSettle();
    final group = tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>));
    expect(group.groupValue, 'dirty');
  });

  testWidgets('multiple selection: any number, at least one to answer', (tester) async {
    await open(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Noise'));
    await tester.tap(find.text('Leak'));
    await tester.pumpAndSettle();
    expect(checked(tester, 'leak'), isTrue);
    expect(checked(tester, 'smell'), isFalse);
    expect(checked(tester, 'noise'), isTrue);
    expect(find.textContaining('1 answered'), findsOneWidget);

    await tester.tap(find.text('Leak'));
    await tester.tap(find.text('Noise'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0 answered'), findsOneWidget);
  });
}
