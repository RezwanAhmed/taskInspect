import 'package:flutter/material.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/checkbox_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/multi_choice_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/number_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/single_choice_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/text_answer_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/yes_no_input.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// Changes an answer. It receives the latest answer, so quick successive
/// changes (two taps in one frame) never overwrite each other.
typedef AnswerUpdate = Answer Function(Answer current);

/// The input that fits a requirement's type, or `null` when it is not
/// built yet (the screen shows a placeholder).
Widget? requirementInput({
  required Requirement requirement,
  required Answer answer,
  required void Function(AnswerUpdate update) onChanged,
}) {
  return switch (requirement.type) {
    RequirementType.checkbox => CheckboxInput(
        value: answer.booleanValue ?? false,
        onChanged: (value) => onChanged((a) => a.copyWith(booleanValue: () => value)),
      ),
    RequirementType.yesNo => YesNoInput(
        value: answer.booleanValue,
        onChanged: (value) => onChanged((a) => a.copyWith(booleanValue: () => value)),
      ),
    RequirementType.text || RequirementType.comment => TextAnswerInput(
        key: ValueKey('text-${requirement.id}'),
        value: answer.textValue,
        hint: requirement.type == RequirementType.comment ? 'Your comment' : 'Your answer',
        onChanged: (value) => onChanged((a) => a.copyWith(textValue: () => value)),
      ),
    RequirementType.number => NumberInput(
        key: ValueKey('number-${requirement.id}'),
        value: answer.numberValue,
        unit: requirement.unit,
        onChanged: (value) => onChanged((a) => a.copyWith(numberValue: () => value)),
      ),
    RequirementType.dropdown => SingleChoiceInput(
        options: requirement.options,
        selectedId: answer.selectedOptionIds.firstOrNull,
        onChanged: (id) => onChanged((a) => a.copyWith(selectedOptionIds: [id])),
      ),
    RequirementType.multipleSelection => MultiChoiceInput(
        options: requirement.options,
        selectedIds: answer.selectedOptionIds,
        onToggled: (id, checked) => onChanged((a) {
          final selected = {...a.selectedOptionIds};
          checked ? selected.add(id) : selected.remove(id);
          return a.copyWith(selectedOptionIds: [
            for (final option in requirement.options)
              if (selected.contains(option.id)) option.id,
          ]);
        }),
      ),
    _ => null,
  };
}
