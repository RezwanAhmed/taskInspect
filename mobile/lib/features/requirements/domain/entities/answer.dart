import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// The worker's answer to one requirement. Only the value that fits the
/// requirement type is set (same shape as the backend's response).
class Answer extends Equatable {
  const Answer({this.booleanValue, this.textValue, this.numberValue, this.selectedOptionIds = const [], this.comment});

  final bool? booleanValue;
  final String? textValue;
  final num? numberValue;
  final List<String> selectedOptionIds;

  /// An optional note on any requirement.
  final String? comment;

  /// Whether this answer completes [requirement] (a comment alone doesn't).
  bool completes(Requirement requirement) => switch (requirement.type) {
        RequirementType.checkbox => booleanValue ?? false,
        RequirementType.yesNo => booleanValue != null,
        RequirementType.text || RequirementType.comment => (textValue ?? '').trim().isNotEmpty,
        RequirementType.number => numberValue != null,
        RequirementType.dropdown => selectedOptionIds.length == 1,
        RequirementType.multipleSelection => selectedOptionIds.isNotEmpty,
        // Answered with evidence files (tasks 5.14-5.18).
        RequirementType.photo || RequirementType.document => false,
      };

  Answer copyWith({
    bool? Function()? booleanValue,
    String? Function()? textValue,
    num? Function()? numberValue,
    List<String>? selectedOptionIds,
    String? Function()? comment,
  }) {
    return Answer(
      booleanValue: booleanValue != null ? booleanValue() : this.booleanValue,
      textValue: textValue != null ? textValue() : this.textValue,
      numberValue: numberValue != null ? numberValue() : this.numberValue,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      comment: comment != null ? comment() : this.comment,
    );
  }

  @override
  List<Object?> get props => [booleanValue, textValue, numberValue, selectedOptionIds, comment];
}
