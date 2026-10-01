import 'package:flutter/material.dart';
import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/checkbox_input.dart';
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
    _ => null,
  };
}
