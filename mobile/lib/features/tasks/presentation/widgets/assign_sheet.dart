import 'package:flutter/material.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/failure_messages.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/authentication/domain/entities/auth_user.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/entities/worker_option.dart';
import 'package:taskinspect/features/tasks/domain/usecases/assign_task.dart';

/// Assign a draft to a worker (the manager's team first) or publish it as
/// an open task for the team or everyone. Online only. Closes with a
/// message to show, or `null` when nothing was done.
class AssignSheet extends StatefulWidget {
  const AssignSheet({required this.taskId, required this.user, super.key});

  final String taskId;
  final AuthUser user;

  static Future<String?> show(BuildContext context, String taskId, AuthUser user) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AssignSheet(taskId: taskId, user: user),
      );

  @override
  State<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<AssignSheet> {
  final _assignTask = getIt<AssignTask>();
  late Future<Result<List<WorkerOption>>> _workers = _assignTask.workers(widget.user);
  var _busy = false;
  String? _error;

  Future<void> _run(Future<Result<Task>> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) {
      return;
    }
    switch (result) {
      case Ok():
        Navigator.pop(context, done);
      case Err(:final failure):
        setState(() {
          _busy = false;
          _error = _message(failure);
        });
    }
  }

  static String _message(Failure failure) => switch (failure) {
        NetworkFailure() => 'No connection. Assigning and publishing need the internet.',
        ServerFailure(code: 'TASK_HAS_NO_REQUIREMENTS') => 'Add at least one requirement first.',
        ServerFailure(code: 'TEAM_HAS_NO_MEMBERS') => 'Your team has no active workers. Publish to everyone instead.',
        ServerFailure(code: 'REVIEWER_IS_ASSIGNEE') =>
          'The reviewer cannot also be the worker. Choose another worker or change the reviewer.',
        InvalidInputFailure(:final message) => message,
        _ => userMessage(failure),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Assign or publish', style: theme.textTheme.titleLarge),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, key: const Key('assign-error'), style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 8),
              Text('Publish as an open task', style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _assignTask.publish(widget.taskId, OpenScope.team), 'Published to your team.'),
                    child: const Text('To my team'),
                  ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() => _assignTask.publish(widget.taskId, OpenScope.everyone),
                            'Published to every worker.'),
                    child: const Text('To everyone'),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Or assign to a worker', style: theme.textTheme.titleSmall),
              Flexible(
                child: FutureBuilder<Result<List<WorkerOption>>>(
                  future: _workers,
                  builder: (context, snapshot) => switch (snapshot.data) {
                    null => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                    Err(:final failure) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_message(failure), key: const Key('workers-error')),
                          TextButton(
                            onPressed: () => setState(() => _workers = _assignTask.workers(widget.user)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    Ok(value: []) => const Text('No active workers.'),
                    Ok(:final value) => ListView(
                        shrinkWrap: true,
                        children: [
                          for (final worker in value)
                            ListTile(
                              enabled: !_busy,
                              leading: const Icon(Icons.engineering_outlined),
                              title: Text(worker.name),
                              subtitle: worker.inMyTeam ? const Text('My team') : null,
                              onTap: () => _run(() => _assignTask.assign(widget.taskId, worker.id),
                                  'Assigned to ${worker.name}.'),
                            ),
                        ],
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
