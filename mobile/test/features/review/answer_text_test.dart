import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/review/presentation/answer_text.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

Requirement _requirement(RequirementType type, {String? unit, List<RequirementOption> options = const []}) =>
    Requirement(id: 'r', taskId: 't', title: 'Q', type: type, required: true, position: 0, unit: unit,
        options: options);

void main() {
  test('answers in words', () {
    expect(describeAnswer(_requirement(RequirementType.yesNo), const Answer(booleanValue: false)), 'No');
    expect(describeAnswer(_requirement(RequirementType.checkbox), const Answer(booleanValue: true)), 'Checked');
    expect(describeAnswer(_requirement(RequirementType.number, unit: '°C'), const Answer(numberValue: 4.0)), '4 °C');
    expect(describeAnswer(_requirement(RequirementType.number), const Answer(numberValue: 4.5)), '4.5');
    expect(describeAnswer(_requirement(RequirementType.text), const Answer(textValue: '  Clean  ')), 'Clean');
    const options = [RequirementOption(id: 'o1', label: 'Good', position: 0), RequirementOption(id: 'o2', label: 'Bad', position: 1)];
    expect(
      describeAnswer(_requirement(RequirementType.multipleSelection, options: options),
          const Answer(selectedOptionIds: ['o1', 'o2'])),
      'Good, Bad',
    );
  });

  test('missing answers', () {
    expect(describeAnswer(_requirement(RequirementType.yesNo), null), 'No answer');
    expect(describeAnswer(_requirement(RequirementType.text), const Answer(textValue: ' ')), 'No answer');
    expect(describeAnswer(_requirement(RequirementType.photo), null), '', reason: 'files are shown instead');
  });
}
