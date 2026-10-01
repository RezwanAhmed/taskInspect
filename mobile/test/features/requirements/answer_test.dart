import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

Requirement of(RequirementType type) =>
    Requirement(id: 'r', taskId: 't', title: 'x', type: type, required: true, position: 0);

void main() {
  test('checkbox is complete only when ticked', () {
    expect(const Answer(booleanValue: true).completes(of(RequirementType.checkbox)), isTrue);
    expect(const Answer(booleanValue: false).completes(of(RequirementType.checkbox)), isFalse);
    expect(const Answer().completes(of(RequirementType.checkbox)), isFalse);
  });

  test('yes/no is complete with either answer', () {
    expect(const Answer(booleanValue: false).completes(of(RequirementType.yesNo)), isTrue);
    expect(const Answer().completes(of(RequirementType.yesNo)), isFalse);
  });

  test('a comment alone does not complete a requirement', () {
    expect(const Answer(comment: 'checked').completes(of(RequirementType.yesNo)), isFalse);
  });

  test('other types', () {
    expect(const Answer(textValue: '  ').completes(of(RequirementType.text)), isFalse);
    expect(const Answer(textValue: 'ok').completes(of(RequirementType.comment)), isTrue);
    expect(const Answer(numberValue: 0).completes(of(RequirementType.number)), isTrue);
    expect(const Answer(selectedOptionIds: ['a']).completes(of(RequirementType.dropdown)), isTrue);
    expect(const Answer(selectedOptionIds: ['a', 'b']).completes(of(RequirementType.dropdown)), isFalse);
    expect(const Answer(selectedOptionIds: ['a', 'b']).completes(of(RequirementType.multipleSelection)), isTrue);
    expect(const Answer(textValue: 'x').completes(of(RequirementType.photo)), isFalse);
  });
}
