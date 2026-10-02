import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement_draft.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/edit_requirements.dart';
import 'package:taskinspect/features/tasks/domain/usecases/save_draft_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';

/// The task's creator adds, changes, deletes and orders its requirements
/// (Phase 7B). Works offline: every change is saved on the phone and sent
/// at the next sync.
class RequirementEditorPage extends StatefulWidget {
  const RequirementEditorPage({required this.taskId, super.key});

  final String taskId;

  @override
  State<RequirementEditorPage> createState() => _RequirementEditorPageState();
}

class _RequirementEditorPageState extends State<RequirementEditorPage> {
  final _edit = getIt<EditRequirements>();
  late final StreamSubscription<Task?> _taskSubscription;
  late final StreamSubscription<List<Requirement>> _requirementSubscription;
  Task? _task;
  List<Requirement> _requirements = const [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final watch = getIt<WatchTaskDetails>();
    _taskSubscription = watch.task(widget.taskId).listen((task) => setState(() {
          _task = task;
          _loading = false;
        }));
    _requirementSubscription =
        watch.requirements(widget.taskId).listen((requirements) => setState(() => _requirements = requirements));
  }

  @override
  void dispose() {
    _taskSubscription.cancel();
    _requirementSubscription.cancel();
    super.dispose();
  }

  void _show(Result<Object?> result) {
    if (result case Err(:final failure) when mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage(failure))));
    }
  }

  Future<void> _openSheet([Requirement? requirement]) async {
    final draft = await showModalBottomSheet<RequirementDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequirementSheet(initial: requirement),
    );
    if (draft == null) {
      return;
    }
    _show(requirement == null
        ? await _edit.add(widget.taskId, draft)
        : await _edit.update(widget.taskId, requirement.id, draft));
  }

  Future<void> _delete(Requirement requirement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete requirement?'),
        content: Text(requirement.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed ?? false) {
      _show(await _edit.delete(widget.taskId, requirement.id));
    }
  }

  /// [newIndex] is where the item ends up (onReorderItem already allows for its removal).
  Future<void> _move(int oldIndex, int newIndex) async {
    final ids = [for (final requirement in _requirements) requirement.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    _show(await _edit.reorder(widget.taskId, ids));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth is Authenticated ? auth.user : null;
    final allowed = _task != null && user != null && SaveDraftTask.canEdit(_task!, user);
    return Scaffold(
      appBar: AppBar(title: const Text('Requirements')),
      floatingActionButton: allowed
          ? FloatingActionButton.extended(
              key: const Key('add-requirement'),
              onPressed: _openSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add requirement'),
            )
          : null,
      body: switch ((_loading, allowed)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (false, false) => const Center(child: Text('This task can no longer be edited.')),
        _ when _requirements.isEmpty => const Center(child: Text('No requirements yet. Add the first one.')),
        _ => ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: _requirements.length,
            onReorderItem: _move,
            itemBuilder: (context, index) {
              final requirement = _requirements[index];
              return ListTile(
                key: ValueKey(requirement.id),
                leading: Icon(RequirementTypeLook.icon(requirement.type)),
                title: Text(requirement.title),
                subtitle: Text(RequirementTypeLook.label(requirement.type) +
                    (requirement.required ? ' · Required' : ' · Optional')),
                onTap: () => _openSheet(requirement),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete ${requirement.title}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(requirement),
                    ),
                    ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                  ],
                ),
              );
            },
          ),
      },
    );
  }
}

/// The form for one requirement; pops with the [RequirementDraft].
class _RequirementSheet extends StatefulWidget {
  const _RequirementSheet({this.initial});

  final Requirement? initial;

  @override
  State<_RequirementSheet> createState() => _RequirementSheetState();
}

class _RequirementSheetState extends State<_RequirementSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _unit = TextEditingController(text: widget.initial?.unit);
  late final _options =
      TextEditingController(text: widget.initial?.options.map((option) => option.label).join('\n'));
  late var _type = widget.initial?.type ?? RequirementType.yesNo;
  late var _required = widget.initial?.required ?? true;
  String? _problem;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _unit.dispose();
    _options.dispose();
    super.dispose();
  }

  void _save() {
    String? clean(String text) => text.trim().isEmpty ? null : text.trim();
    final draft = RequirementDraft(
      title: _title.text.trim(),
      description: clean(_description.text),
      type: _type,
      required: _required,
      unit: _type == RequirementType.number ? clean(_unit.text) : null,
      options: _type.hasOptions
          ? [for (final line in _options.text.split('\n')) if (line.trim().isNotEmpty) line.trim()]
          : const [],
    );
    final problem = EditRequirements.problem(draft);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.initial == null ? 'New requirement' : 'Edit requirement',
                style: Theme.of(context).textTheme.titleLarge),
            TextField(
              key: const Key('requirement-title'),
              controller: _title,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _description,
              maxLength: 5000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            DropdownButtonFormField<RequirementType>(
              key: const Key('requirement-type'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final type in RequirementType.values)
                  DropdownMenuItem(value: type, child: Text(RequirementTypeLook.label(type))),
              ],
              onChanged: (type) => setState(() => _type = type ?? _type),
            ),
            if (_type == RequirementType.number)
              TextField(
                controller: _unit,
                maxLength: 30,
                decoration: const InputDecoration(labelText: 'Unit (optional, e.g. °C)'),
              ),
            if (_type.hasOptions)
              TextField(
                key: const Key('requirement-options'),
                controller: _options,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Options (one per line)'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            FilledButton(key: const Key('save-requirement'), onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
