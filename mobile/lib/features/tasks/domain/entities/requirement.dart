import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// One choice of a dropdown or multiple-selection requirement.
class RequirementOption extends Equatable {
  const RequirementOption({required this.id, required this.label, required this.position});

  final String id;
  final String label;
  final int position;

  @override
  List<Object?> get props => [id, label, position];
}

/// One item of a task that the worker completes.
class Requirement extends Equatable {
  const Requirement({
    required this.id,
    required this.taskId,
    required this.title,
    required this.type,
    required this.required,
    required this.position,
    this.description,
    this.unit,
    this.options = const [],
  });

  final String id;
  final String taskId;
  final String title;
  final String? description;
  final RequirementType type;
  final bool required;
  final int position;

  /// For NUMBER requirements, e.g. °C.
  final String? unit;
  final List<RequirementOption> options;

  @override
  List<Object?> get props => [id, taskId, title, description, type, required, position, unit, options];
}
