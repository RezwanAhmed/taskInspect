import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/router/app_router.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/save_draft_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/task_tile.dart';

/// A manager creates a draft task ([taskId] `null`) or edits one (Phase 7B).
/// Works offline: the task is saved on the phone and sent at the next sync.
/// With [mainTaskId] it adds a sub-task to that main task instead, which
/// needs a connection. The creator reviews the task; choosing another
/// reviewer comes later.
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({this.taskId, this.mainTaskId, super.key});

  final String? taskId;
  final String? mainTaskId;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  var _priority = TaskPriority.medium;
  late DateTime _due = _tomorrowAtNine();
  Task? _existing;
  var _loading = true;
  var _saving = false;

  bool get _isNew => widget.taskId == null;

  bool get _isSubTask => widget.mainTaskId != null;

  static DateTime _tomorrowAtNine() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9);
  }

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _loading = false;
    } else {
      getIt<WatchTaskDetails>().task(widget.taskId!).first.then((task) {
        if (!mounted) {
          return;
        }
        setState(() {
          _existing = task;
          _loading = false;
          if (task != null) {
            _title.text = task.title;
            _description.text = task.description ?? '';
            _priority = task.priority;
            _due = task.dueDate.toLocal();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: _due.isBefore(DateTime.now()) ? _due : DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (!mounted) {
      return;
    }
    setState(() => _due = DateTime(date.year, date.month, date.day, time?.hour ?? _due.hour, time?.minute ?? _due.minute));
  }

  Future<void> _save() async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! Authenticated || !_form.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    final description = _description.text.trim();
    final draft = TaskDraft(
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      priority: _priority,
      dueDate: _due.toUtc(),
      reviewer: _existing?.reviewer.id == _existing?.createdBy.id ? null : _existing?.reviewer,
    );
    final saveDraft = getIt<SaveDraftTask>();
    final result = _isSubTask
        ? await saveDraft.createSubTask(widget.mainTaskId!, draft)
        : _isNew
            ? await saveDraft.create(draft, auth.user)
            : await saveDraft.update(widget.taskId!, draft);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    switch (result) {
      case Ok(:final value):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSubTask
                ? 'Sub-task added. Open it to add requirements and assign it.'
                : _isNew
                    ? 'Draft saved. It is sent at the next sync.'
                    : 'Changes saved.'),
          ),
        );
        if (_isNew && !_isSubTask) {
          context.pushReplacement(AppRoutes.task(value.id));
        } else {
          // Back to the details (edit) or the main task, whose panel reloads its sub-tasks.
          context.pop();
        }
      case Err(:final failure):
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(switch (failure) {
            NetworkFailure() => 'No connection. Adding a sub-task needs the internet.',
            ServerFailure(code: 'MAIN_TASK_CLOSED') => 'The main task no longer takes new sub-tasks.',
            _ => userMessage(failure),
          }),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final allowed = user != null &&
        (_isNew ? SaveDraftTask.canCreate(user) : _existing != null && SaveDraftTask.canEdit(_existing!, user));
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSubTask ? 'New sub-task' : _isNew ? 'New task' : 'Edit task'),
        actions: [
          if (!_loading && allowed)
            TextButton(
              key: const Key('save-task'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: switch ((_loading, allowed)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (false, false) => Center(
            child: Text(_isNew ? 'Only managers can create tasks.' : 'This task can no longer be edited.'),
          ),
        _ => Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  key: const Key('task-title'),
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a title' : null,
                ),
                TextFormField(
                  key: const Key('task-description'),
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLength: 5000,
                  minLines: 2,
                  maxLines: 6,
                ),
                const SizedBox(height: 8),
                Text('Priority', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<TaskPriority>(
                  segments: const [
                    ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                    ButtonSegment(value: TaskPriority.medium, label: Text('Medium')),
                    ButtonSegment(value: TaskPriority.high, label: Text('High')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (selection) => setState(() => _priority = selection.single),
                ),
                const SizedBox(height: 16),
                ListTile(
                  key: const Key('task-due'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Deadline'),
                  subtitle: Text(TaskTile.formatDue(_due)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickDue,
                ),
              ],
            ),
          ),
      },
    );
  }
}
