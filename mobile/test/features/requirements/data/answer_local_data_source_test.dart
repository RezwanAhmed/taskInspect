import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
import 'package:taskinspect/core/synchronization/sync_queue.dart';
import 'package:taskinspect/features/requirements/data/local/answer_local_data_source.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/data/local/task_local_data_source.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

import '../../../helpers/fake_tasks.dart';

void main() {
  late AppDatabase db;
  late AnswerLocalDataSource answers;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    answers = AnswerLocalDataSource(db, SyncQueue(db));
    await TaskLocalDataSource(db).saveTask(fakeTask('t1', status: TaskStatus.inProgress), const [
      Requirement(id: 'r1', taskId: 't1', title: 'Ok?', type: RequirementType.yesNo, required: true, position: 0),
      Requirement(id: 'r2', taskId: 't1', title: 'Temp', type: RequirementType.number, required: true, position: 1),
      Requirement(id: 'r3', taskId: 't1', title: 'Problems', type: RequirementType.multipleSelection,
          required: true, position: 2),
    ]);
  });

  tearDown(() => db.close());

  test('saves answers of every kind and reads them back', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r1',
        answer: const Answer(booleanValue: false, comment: 'Door seal is worn'));
    await answers.saveAnswer(taskId: 't1', requirementId: 'r2', answer: const Answer(numberValue: 3.5));
    await answers.saveAnswer(taskId: 't1', requirementId: 'r3',
        answer: const Answer(selectedOptionIds: ['leak', 'noise']));

    final saved = await answers.watchAnswers('t1').first;

    expect(saved['r1'], const Answer(booleanValue: false, comment: 'Door seal is worn'));
    expect(saved['r2']!.numberValue, 3.5);
    expect(saved['r3']!.selectedOptionIds, ['leak', 'noise']);
  });

  test('saving again replaces the answer; whole numbers stay whole', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r2', answer: const Answer(numberValue: 3.5));
    await answers.saveAnswer(taskId: 't1', requirementId: 'r2', answer: const Answer(numberValue: 4));

    final saved = await answers.watchAnswers('t1').first;
    expect(saved, hasLength(1));
    expect(saved['r2']!.numberValue, 4);
    expect(saved['r2']!.numberValue, isA<int>());
  });

  test('every save waits to be sent to the server', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r1', answer: const Answer(booleanValue: true));

    expect(await answers.pendingRequirementIds('t1'), ['r1']);
  });

  test('answers are removed with their task', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r1', answer: const Answer(booleanValue: true));

    await TaskLocalDataSource(db).deleteTasksExcept({});

    expect(await answers.watchAnswers('t1').first, isEmpty);
  });

  test('a save is queued for the server with the whole answer', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r3',
        answer: const Answer(selectedOptionIds: ['leak'], comment: 'Under the sink'));

    final queued = await db.select(db.localSyncOperations).getSingle();

    expect(queued.entityType, 'TaskResponse');
    expect(queued.entityId, 'r3');
    expect(queued.taskId, 't1');
    expect(queued.operation, 'UPDATE');
    expect(queued.status, 'PENDING');
    expect(jsonDecode(queued.payload), {
      'booleanValue': null,
      'textValue': null,
      'numberValue': null,
      'selectedOptionIds': ['leak'],
      'comment': 'Under the sink',
    });
  });

  test('typing again keeps one queued update with the latest answer', () async {
    await answers.saveAnswer(taskId: 't1', requirementId: 'r2', answer: const Answer(numberValue: 3));
    await answers.saveAnswer(taskId: 't1', requirementId: 'r2', answer: const Answer(numberValue: 35));

    final queued = await db.select(db.localSyncOperations).get();

    expect(queued, hasLength(1));
    expect((jsonDecode(queued.single.payload) as Map<String, Object?>)['numberValue'], 35);
  });

  test('nothing is queued when the answer cannot be saved', () async {
    // No such requirement or task on the device: the foreign keys refuse it.
    await expectLater(
      answers.saveAnswer(taskId: 'missing', requirementId: 'missing', answer: const Answer(booleanValue: true)),
      throwsA(anything),
    );

    expect(await db.select(db.localSyncOperations).get(), isEmpty);
  });
}
