import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/repositories/task_repository.dart';

/// A manager creates a draft task or changes one (works offline; Phase 7B).
class SaveDraftTask {
  const SaveDraftTask(this._repository);

  final TaskRepository _repository;

  /// Statuses in which the creator can still change a task (the server's rule).
  static const editable = {TaskStatus.draft, TaskStatus.open, TaskStatus.assigned};

  static bool canCreate(AuthUser user) => user.isManager;

  static bool canEdit(Task task, AuthUser user) =>
      user.isManager && task.createdBy.id == user.id && editable.contains(task.status);

  Future<Result<Task>> create(TaskDraft draft, AuthUser user) =>
      _repository.createDraft(draft, creator: PersonRef(id: user.id, name: user.fullName));

  Future<Result<Task>> update(String taskId, TaskDraft draft) => _repository.updateDraft(taskId, draft);
}
