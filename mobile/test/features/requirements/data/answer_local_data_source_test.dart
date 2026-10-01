import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/storage/app_database.dart';
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
    answers = AnswerLocalDataSource(db);
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
}
