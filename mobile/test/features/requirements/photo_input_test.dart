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

  Future<FakeEvidencePicker> open(WidgetTester tester) async {
    final picker = FakeEvidencePicker();
    registerFakeTasks(
      FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
        ..requirements = {
          't1': const [
            Requirement(id: 'r1', taskId: 't1', title: 'Take a photo of the refrigerator',
                type: RequirementType.photo, required: true, position: 0),
          ],
        },
      picker: picker,
    );
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
    return picker;
  }

  testWidgets('camera and gallery photos are shown and answer the requirement', (tester) async {
    final picker = await open(tester);
    expect(find.textContaining('0 answered'), findsOneWidget);

    picker.next.add('/photos/fridge-1.jpg');
    await tester.tap(find.byKey(const Key('take-photo')));
    await tester.pumpAndSettle();
    expect(picker.cameraUses, 1);
    expect(find.byKey(const Key('photo-0')), findsOneWidget);
    expect(find.textContaining('1 answered'), findsOneWidget);

    picker.next.add('/photos/fridge-2.jpg');
    await tester.tap(find.byKey(const Key('choose-photo')));
    await tester.pumpAndSettle();
    expect(picker.galleryUses, 1);
    expect(find.byKey(const Key('photo-1')), findsOneWidget);
  });

  testWidgets('cancelling the camera changes nothing', (tester) async {
    final picker = await open(tester);

    await tester.tap(find.byKey(const Key('take-photo')));
    await tester.pumpAndSettle();

    expect(picker.cameraUses, 1);
    expect(find.byKey(const Key('photo-0')), findsNothing);
    expect(find.textContaining('0 answered'), findsOneWidget);
  });
}
