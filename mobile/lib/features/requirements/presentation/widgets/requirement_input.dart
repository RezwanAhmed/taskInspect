import 'package:flutter/material.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/checkbox_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/number_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/text_answer_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/yes_no_input.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// The input that fits a requirement's type, or `null` when it is not
/// built yet (the screen shows a placeholder).
Widget? requirementInput({
  required Requirement requirement,
  required Answer answer,
  required ValueChanged<Answer> onChanged,
}) {
  return switch (requirement.type) {
    RequirementType.checkbox => CheckboxInput(
        value: answer.booleanValue ?? false,
        onChanged: (value) => onChanged(answer.copyWith(booleanValue: () => value)),
      ),
    RequirementType.yesNo => YesNoInput(
        value: answer.booleanValue,
        onChanged: (value) => onChanged(answer.copyWith(booleanValue: () => value)),
      ),
    RequirementType.text || RequirementType.comment => TextAnswerInput(
        key: ValueKey('text-${requirement.id}'),
        value: answer.textValue,
        hint: requirement.type == RequirementType.comment ? 'Your comment' : 'Your answer',
        onChanged: (value) => onChanged(answer.copyWith(textValue: () => value)),
      ),
    RequirementType.number => NumberInput(
        key: ValueKey('number-${requirement.id}'),
        value: answer.numberValue,
        unit: requirement.unit,
        onChanged: (value) => onChanged(answer.copyWith(numberValue: () => value)),
      ),
    _ => null,
  };
}
