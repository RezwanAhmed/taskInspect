import 'package:equatable/equatable.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';

/// What a manager enters for a new or changed requirement (Phase 7B).
/// [unit] only for NUMBER, [options] (at least two) only for DROPDOWN and
/// MULTIPLE_SELECTION - the server's rules.
class RequirementDraft extends Equatable {
  const RequirementDraft({
    required this.title,
    required this.type,
    this.description,
    this.required = true,
    this.unit,
    this.options = const [],
  });

  final String title;
  final String? description;
  final RequirementType type;
  final bool required;
  final String? unit;
  final List<String> options;

  @override
  List<Object?> get props => [title, description, type, required, unit, options];
}
