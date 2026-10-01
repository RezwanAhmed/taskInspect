import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  tearDown(getIt.reset);

  late FakeEvidencePicker picker;
  late FakeEvidenceRepository evidence;
  late FakeDocumentOpener opener;

  Future<void> open(WidgetTester tester) async {
    picker = FakeEvidencePicker();
    evidence = FakeEvidenceRepository();
    opener = FakeDocumentOpener();
    registerFakeTasks(
      FakeTaskRepository([fakeTask('t1', status: TaskStatus.inProgress)])
        ..requirements = {
          't1': const [
            Requirement(id: 'r1', taskId: 't1', title: 'Attach the service report',
                type: RequirementType.document, required: true, position: 0),
          ],
        },
      picker: picker,
      evidence: evidence,
      opener: opener,
    );
    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository(savedUser: testWorker))));
    await tester.pumpAndSettle();
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push(AppRoutes.execute('t1')));
    await tester.pumpAndSettle();
  }

  testWidgets('a chosen PDF is listed with its name and answers the requirement', (tester) async {
    await open(tester);
    expect(find.textContaining('0 answered'), findsOneWidget);
    expect(find.text('Choose PDF'), findsOneWidget);

    picker.nextDocuments.add(const PickedDocument(path: '/files/report.pdf', name: 'Service report.pdf'));
    await tester.tap(find.byKey(const Key('choose-document')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document-0')), findsOneWidget);
    expect(find.text('Service report.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    expect(find.textContaining('1 answered'), findsOneWidget);
    expect(find.text('Add another PDF'), findsOneWidget);
  });

  testWidgets('cancelling the file picker changes nothing', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('choose-document')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('document-0')), findsNothing);
    expect(evidence.items, isEmpty);
  });

  testWidgets('a rejected file shows why', (tester) async {
    await open(tester);
    evidence.addError = const EvidenceRejected('The PDF is larger than 20 MB.');
    picker.nextDocuments.add(const PickedDocument(path: '/files/big.pdf', name: 'big.pdf'));

    await tester.tap(find.byKey(const Key('choose-document')));
    await tester.pumpAndSettle();

    expect(find.text('The PDF is larger than 20 MB.'), findsOneWidget);
    expect(find.byKey(const Key('document-0')), findsNothing);
  });

  testWidgets('tapping a document opens it; without a PDF app a message is shown', (tester) async {
    await open(tester);
    picker.nextDocuments.add(const PickedDocument(path: '/files/report.pdf', name: 'report.pdf'));
    await tester.tap(find.byKey(const Key('choose-document')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();
    expect(opener.opened, ['/files/report.pdf']);

    opener.canOpen = false;
    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('No app on this device can open PDF documents.'), findsOneWidget);
  });

  testWidgets('a document is removed only after confirming', (tester) async {
    await open(tester);
    picker.nextDocuments.add(const PickedDocument(path: '/files/report.pdf', name: 'report.pdf'));
    await tester.tap(find.byKey(const Key('choose-document')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remove-document-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('remove-document-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('document-0')), findsNothing);
    expect(find.textContaining('0 answered'), findsOneWidget);
  });
}
