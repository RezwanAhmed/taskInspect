import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement_draft.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// The task's creator adds, changes, deletes and orders its requirements
/// while the task can still be edited (works offline; Phase 7B). Who may
/// do it: SaveDraftTask.canEdit.
class EditRequirements {
  const EditRequirements(this._repository);

  final TaskRepository _repository;

  /// The options a requirement of this type needs, or a reason why the
  /// draft can't be saved (the server's rules); `null` when it is fine.
  static String? problem(RequirementDraft draft) {
    if (draft.title.trim().isEmpty) {
      return 'Enter a title';
    }
    if (draft.type.hasOptions && draft.options.where((o) => o.trim().isNotEmpty).length < 2) {
      return 'Add at least two options';
    }
    return null;
  }

  Future<Result<Requirement>> add(String taskId, RequirementDraft draft) => _repository.addRequirement(taskId, draft);

  Future<Result<void>> update(String taskId, String requirementId, RequirementDraft draft) =>
      _repository.updateRequirement(taskId, requirementId, draft);

  Future<Result<void>> delete(String taskId, String requirementId) =>
      _repository.deleteRequirement(taskId, requirementId);

  Future<Result<void>> reorder(String taskId, List<String> requirementIds) =>
      _repository.reorderRequirements(taskId, requirementIds);
}
