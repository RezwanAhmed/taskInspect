import 'package:taskinspect/features/requirements/domain/entities/answer.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// The worker's answer in words, as the reviewer reads it.
String describeAnswer(Requirement requirement, Answer? answer) {
  const none = 'No answer';
  if (answer == null) {
    return requirement.type.isEvidence ? '' : none;
  }
  String labels(List<String> ids) => [
        for (final id in ids) requirement.options.where((o) => o.id == id).firstOrNull?.label ?? id,
      ].join(', ');
  return switch (requirement.type) {
    RequirementType.checkbox => answer.booleanValue == null ? none : (answer.booleanValue! ? 'Checked' : 'Not checked'),
    RequirementType.yesNo => answer.booleanValue == null ? none : (answer.booleanValue! ? 'Yes' : 'No'),
    RequirementType.text || RequirementType.comment =>
      (answer.textValue ?? '').trim().isEmpty ? none : answer.textValue!.trim(),
    RequirementType.number => answer.numberValue == null
        ? none
        : '${_number(answer.numberValue!)}${requirement.unit == null ? '' : ' ${requirement.unit}'}',
    RequirementType.dropdown || RequirementType.multipleSelection =>
      answer.selectedOptionIds.isEmpty ? none : labels(answer.selectedOptionIds),
    RequirementType.photo || RequirementType.document => '',
  };
}

/// 4 instead of 4.0; other numbers as they are.
String _number(num value) => value == value.truncate() ? value.truncate().toString() : value.toString();
