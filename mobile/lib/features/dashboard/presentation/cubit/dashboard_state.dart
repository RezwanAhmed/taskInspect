part of 'dashboard_cubit.dart';

/// Task counts for the dashboard.
class DashboardState extends Equatable {
  const DashboardState({
    this.counts = const {},
    this.overdue = 0,
    this.isLoading = true,
    this.isRefreshing = false,
    this.message,
  });

  /// Number of tasks per status (statuses without tasks are missing).
  final Map<TaskStatus, int> counts;

  /// Open tasks past their due date.
  final int overdue;

  /// True until the first counts from the device are known.
  final bool isLoading;

  final bool isRefreshing;

  /// Shown when loading from the server failed (e.g. offline).
  final String? message;

  int count(TaskStatus status) => counts[status] ?? 0;

  int get total => counts.values.fold(0, (sum, value) => sum + value);

  DashboardState copyWith({
    Map<TaskStatus, int>? counts,
    int? overdue,
    bool? isLoading,
    bool? isRefreshing,
    String? Function()? message,
  }) {
    return DashboardState(
      counts: counts ?? this.counts,
      overdue: overdue ?? this.overdue,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      message: message != null ? message() : this.message,
    );
  }

  @override
  List<Object?> get props => [counts, overdue, isLoading, isRefreshing, message];
}
