import 'dart:async';
import 'dart:io';

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

  testWidgets('a photo that cannot be saved shows a message', (tester) async {
    final evidence = FakeEvidenceRepository()..addError = const FileSystemException('disk full');
    final picker = FakeEvidencePicker()..next.add('/photos/fridge.jpg');
    registerFakeTasks(
      FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
        ..requirements = {
          't1': const [
            Requirement(id: 'r1', taskId: 't1', title: 'Photo', type: RequirementType.photo, required: true,
                position: 0),
          ],
        },
      picker: picker,
      evidence: evidence,
    );
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('take-photo')));
    await tester.pumpAndSettle();

    expect(find.text('The photo could not be saved. Please try again.'), findsOneWidget);
    expect(find.byKey(const Key('photo-0')), findsNothing);
  });

  testWidgets('a photo opens full screen and can be removed after confirming', (tester) async {
    final picker = await open(tester);
    picker.next.add('/photos/fridge.jpg');
    await tester.tap(find.byKey(const Key('take-photo')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('photo-0')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-evidence')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget, reason: 'cancel keeps the photo');

    await tester.tap(find.byKey(const Key('remove-evidence')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byKey(const Key('photo-0')), findsNothing);
    expect(find.textContaining('0 answered'), findsOneWidget);
  });
}
