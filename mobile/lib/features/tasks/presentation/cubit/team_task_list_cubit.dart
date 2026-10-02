import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/features/tasks/domain/entities/team_task.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_team_tasks.dart';
import 'package:taskinspect/features/tasks/presentation/task_tab.dart';

class TeamTaskListState extends Equatable {
  const TeamTaskListState({this.tasks = const [], this.isLoading = true});

  final List<TeamTask> tasks;
  final bool isLoading;

  @override
  List<Object?> get props => [tasks, isLoading];
}

/// The team members' tasks of one "All tasks" tab, kept up to date with the device.
class TeamTaskListCubit extends Cubit<TeamTaskListState> {
  TeamTaskListCubit(this._watchTeamTasks, this.tab) : super(const TeamTaskListState()) {
    _subscription = _watchTeamTasks().listen((tasks) {
      emit(TeamTaskListState(tasks: tasks.where((task) => tab.matches(task.status)).toList(), isLoading: false));
    });
  }

  final WatchTeamTasks _watchTeamTasks;
  final TeamTaskTab tab;
  late final StreamSubscription<List<TeamTask>> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
