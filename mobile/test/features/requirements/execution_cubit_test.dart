import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';
import 'package:taskinspect/features/evidence/domain/evidence_picker.dart';
import 'package:taskinspect/features/evidence/domain/evidence_repository.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/presentation/cubit/execution_cubit.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_review.dart';
import 'package:taskinspect/features/tasks/domain/usecases/submit_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

import '../../helpers/fake_tasks.dart';

/// Unit tests of the execution cubit: answering, files and submitting (task 9.4c).
void main() {
  const question = Requirement(
      id: 'r1', taskId: '1', title: 'Clean?', type: RequirementType.yesNo, required: true, position: 0);
  const photo = Requirement(
      id: 'r2', taskId: '1', title: 'Fridge photo', type: RequirementType.photo, required: true, position: 1);
  const note = Requirement(
      id: 'r3', taskId: '1', title: 'Anything else?', type: RequirementType.text, required: false, position: 2);
  const report = Requirement(
      id: 'r4', taskId: '1', title: 'Report', type: RequirementType.document, required: false, position: 3);

  late FakeTaskRepository tasks;
  late FakeAnswerRepository answers;
  late FakeEvidencePicker picker;
  late FakeEvidenceRepository evidence;
  late FakeDocumentOpener opener;

  setUp(() {
    tasks = FakeTaskRepository([fakeTask('1', status: TaskStatus.inProgress)])
      ..requirements = {'1': [question, photo, note, report]};
    answers = FakeAnswerRepository();
    picker = FakeEvidencePicker();
    evidence = FakeEvidenceRepository();
    opener = FakeDocumentOpener();
  });

  Future<ExecutionCubit> started() async {
    final cubit = ExecutionCubit(
        WatchTaskDetails(tasks), answers, picker, evidence, opener, SubmitTask(tasks), '1');
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  void correcting(Map<String, String> marked) {
    tasks.reviews = {
      '1': TaskReview(
          result: ReviewResult.correctionRequested,
          reviewerName: 'Mia Manager',
          createdAt: DateTime.utc(2026, 10, 2),
          markedRequirements: marked),
    };
  }

  test('loads the requirements and the answers saved before', () async {
    answers.saved['1'] = {'r1': const Answer(booleanValue: true)};

    final cubit = await started();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.requirements, [question, photo, note, report]);
    expect(cubit.state.current, question);
    expect(cubit.state.answerFor(question).booleanValue, isTrue);
    expect(cubit.state.completedCount, 1);
    await cubit.close();
  });

  test('an answer typed before the saved ones are read is kept', () async {
    // The typed answer is not saved yet when the (older) saved answers arrive.
    final saving = Completer<void>();
    answers
      ..saved['1'] = {'r1': const Answer(booleanValue: true), 'r3': const Answer(textValue: 'Saved')}
      ..saveGate = saving;
    final cubit =
        ExecutionCubit(WatchTaskDetails(tasks), answers, picker, evidence, opener, SubmitTask(tasks), '1');

    cubit.answer(question, (current) => current.copyWith(booleanValue: () => false));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.answerFor(question).booleanValue, isFalse);
    expect(cubit.state.answerFor(note).textValue, 'Saved');
    saving.complete();
    await cubit.close();
  });

  test('moves between requirements and stays within them', () async {
    final cubit = await started();

    cubit.previous();
    expect(cubit.state.index, 0);
    cubit.next();
    expect(cubit.state.current, photo);
    cubit.goTo(3);
    expect(cubit.state.isLast, isTrue);
    cubit.next();
    cubit.goTo(9);
    expect(cubit.state.index, 3);
    await cubit.close();
  });

  test('an answer shows at once and is saved on the device, the last change winning', () async {
    final cubit = await started();

    cubit.answer(note, (current) => current.copyWith(textValue: () => 'First'));
    cubit.answer(note, (current) => current.copyWith(textValue: () => '${current.textValue} and second'));
    expect(cubit.state.answerFor(note).textValue, 'First and second');
    await cubit.saved;

    expect(answers.saved['1']!['r3']!.textValue, 'First and second');
    await cubit.close();
  });

  test('while correcting, only the marked requirements can change', () async {
    correcting({'r2': 'Too dark'});
    final cubit = await started();

    expect(cubit.state.isCorrecting, isTrue);
    expect(cubit.state.isLocked(question), isTrue);
    expect(cubit.state.whatToFix(photo), 'Too dark');
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => false));
    picker.next.add('/tmp/new.jpg');
    await cubit.addPhoto(question, fromCamera: true);

    expect(cubit.state.answerFor(question).booleanValue, isNull);
    expect(picker.cameraUses, 0);
    await cubit.close();
  });

  test('a photo from the camera or the gallery is stored; cancelling changes nothing', () async {
    final cubit = await started();
    picker.next.addAll(['/tmp/a.jpg', null, '/tmp/b.jpg']);

    await cubit.addPhoto(photo, fromCamera: true);
    await cubit.addPhoto(photo, fromCamera: true);
    await cubit.addPhoto(photo, fromCamera: false);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.evidenceFor(photo).map((item) => item.localPath), ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(picker.cameraUses, 2);
    expect(picker.galleryUses, 1);
    expect(cubit.state.isComplete(photo), isTrue);
    expect(cubit.state.evidenceError, isNull);
    await cubit.close();
  });

  test('a photo that cannot be stored shows an error until the next one works', () async {
    final cubit = await started();
    evidence.addError = Exception('disk full');
    picker.next.add('/tmp/a.jpg');

    await cubit.addPhoto(photo, fromCamera: true);
    expect(cubit.state.evidenceError, 'The photo could not be saved. Please try again.');

    evidence.addError = null;
    picker.next.add('/tmp/b.jpg');
    await cubit.addPhoto(photo, fromCamera: true);
    expect(cubit.state.evidenceError, isNull);
    await cubit.close();
  });

  test('a refused document shows the reason, any other failure a general message', () async {
    final cubit = await started();
    picker.nextDocuments.addAll([
      const PickedDocument(path: '/tmp/big.pdf', name: 'big.pdf'),
      const PickedDocument(path: '/tmp/x.pdf', name: 'x.pdf'),
    ]);

    evidence.addError = const EvidenceRejected('The document is larger than 20 MB.');
    await cubit.addDocument(report);
    expect(cubit.state.evidenceError, 'The document is larger than 20 MB.');

    evidence.addError = Exception('disk full');
    await cubit.addDocument(report);
    expect(cubit.state.evidenceError, 'The document could not be saved. Please try again.');
    await cubit.close();
  });

  test('opening a document without a PDF app explains why', () async {
    final cubit = await started();
    final item = EvidenceItem(
        id: 'e1',
        taskId: '1',
        requirementId: 'r4',
        localPath: '/tmp/report.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 10,
        createdAt: DateTime.utc(2026, 10, 1));

    opener.canOpen = false;
    await cubit.openDocument(item);
    expect(cubit.state.evidenceError, 'No app on this device can open PDF documents.');

    opener.canOpen = true;
    await cubit.openDocument(item);
    expect(cubit.state.evidenceError, isNull);
    expect(opener.opened, ['/tmp/report.pdf', '/tmp/report.pdf']);
    await cubit.close();
  });

  test('a file is removed, but not one that stays as submitted during a correction', () async {
    correcting({'r1': 'Check again'});
    await evidence.addPhoto(taskId: '1', requirementId: 'r2', sourcePath: '/tmp/a.jpg');
    final cubit = await started();
    final kept = cubit.state.evidenceFor(photo).single;

    await cubit.removeEvidence(kept);
    expect(evidence.items, hasLength(1));
    await cubit.close();

    tasks.reviews = {};
    final free = await started();
    await free.removeEvidence(kept);
    await Future<void>.delayed(Duration.zero);
    expect(evidence.items, isEmpty);
    expect(free.state.evidenceFor(photo), isEmpty);
    await free.close();
  });

  test('submitting with one missing requirement goes to it and names it', () async {
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));
    cubit.goTo(3);

    await cubit.submit();

    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.isSubmitted, isFalse);
    expect(cubit.state.current, photo);
    expect(cubit.state.message, '"Fridge photo" still needs an answer.');
    expect(tasks.submitted, isEmpty);

    cubit.clearMessage();
    expect(cubit.state.message, isNull);
    await cubit.close();
  });

  test('submitting with several missing requirements counts them', () async {
    final cubit = await started();

    await cubit.submit();

    expect(cubit.state.current, question);
    expect(cubit.state.message, '2 required requirements still need an answer.');
    await cubit.close();
  });

  test('a file missing on the device blocks the submit', () async {
    evidence.items.add(EvidenceItem(
        id: 'e1',
        taskId: '1',
        requirementId: 'r2',
        localPath: '/tmp/gone.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 10,
        createdAt: DateTime.utc(2026, 10, 1),
        fileMissing: true));
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));

    await cubit.submit();

    expect(cubit.state.current, photo);
    expect(cubit.state.message, 'A file of "Fridge photo" is missing on this device. Remove it and add it again.');
    expect(tasks.submitted, isEmpty);
    await cubit.close();
  });

  test('a complete task is submitted after its answers are saved', () async {
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));
    picker.next.add('/tmp/a.jpg');
    await cubit.addPhoto(photo, fromCamera: true);
    await Future<void>.delayed(Duration.zero);

    await cubit.submit();

    expect(answers.saved['1']!['r1']!.booleanValue, isTrue);
    expect(tasks.submitted, ['1']);
    expect(cubit.state.isSubmitted, isTrue);
    expect(cubit.state.isSubmitting, isFalse);
    await cubit.close();
  });

  test('while correcting, only the marked requirements must be complete', () async {
    correcting({'r2': 'Too dark'});
    final cubit = await started();
    picker.next.add('/tmp/new.jpg');
    await cubit.addPhoto(photo, fromCamera: true);
    await Future<void>.delayed(Duration.zero);

    await cubit.submit();

    expect(tasks.submitted, ['1'], reason: 'the unanswered question stays as submitted');
    await cubit.close();
  });

  test('a refused submit shows the reason', () async {
    tasks.submitFailure = const ServerFailure(statusCode: 409, message: 'The task was cancelled');
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));
    picker.next.add('/tmp/a.jpg');
    await cubit.addPhoto(photo, fromCamera: true);
    await Future<void>.delayed(Duration.zero);

    await cubit.submit();

    expect(cubit.state.isSubmitted, isFalse);
    expect(cubit.state.message, 'The task was cancelled');
    await cubit.close();
  });

  // Without the isClosed checks the late results would be stored or emitted on a closed cubit.
  test('a photo taken after the page was closed is not stored', () async {
    final gate = Completer<void>();
    picker
      ..gate = gate
      ..next.add('/tmp/late.jpg');
    final cubit = await started();

    final adding = cubit.addPhoto(photo, fromCamera: true);
    await cubit.close();
    gate.complete();
    await adding;

    expect(evidence.items, isEmpty);
  });

  test('a submit answered after the page was closed is dropped', () async {
    final gate = Completer<void>();
    tasks.submitGate = gate;
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));
    await evidence.addPhoto(taskId: '1', requirementId: 'r2', sourcePath: '/tmp/a.jpg');
    await Future<void>.delayed(Duration.zero);

    final submitting = cubit.submit();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    gate.complete();

    await expectLater(submitting, completes);
  });

  test('a second submit while one is running is ignored', () async {
    final cubit = await started();
    cubit.answer(question, (current) => current.copyWith(booleanValue: () => true));
    picker.next.add('/tmp/a.jpg');
    await cubit.addPhoto(photo, fromCamera: true);
    await Future<void>.delayed(Duration.zero);

    await Future.wait([cubit.submit(), cubit.submit()]);

    expect(tasks.submitted, ['1']);
    await cubit.close();
  });
}
