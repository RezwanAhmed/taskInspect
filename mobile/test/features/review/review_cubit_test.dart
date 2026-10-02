import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/review/domain/review_repository.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/review/presentation/cubit/review_cubit.dart';
import 'package:taskinspect/features/tasks/domain/entities/task.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/watch_task_details.dart';

import '../../helpers/fake_tasks.dart';

class _CountingRepository implements ReviewRepository {
  int urls = 0;

  @override
  Future<Result<Submission>> loadSubmission(String taskId) async => const Ok(Submission());

  @override
  Future<Result<String>> fileUrl(String taskId, SubmittedFile file) async => Ok('http://files.test/${++urls}');

  @override
  Future<Result<String>> downloadFile(String taskId, SubmittedFile file) async => const Ok('/tmp/x');

  @override
  Future<void> clearDownloads(String taskId) async {}

  final List<String> decisions = [];
  Failure? decisionFailure;

  Future<Result<Task>> _decided(String what, TaskStatus status) async {
    decisions.add(what);
    if (decisionFailure != null) {
      return Err(decisionFailure!);
    }
    final task = fakeTask('t1', status: status, title: 'Kitchen');
    return Ok(task);
  }

  @override
  Future<Result<Task>> refreshTask(String taskId) async => Ok(fakeTask('t1'));

  @override
  Future<Result<Task>> approve(String taskId, {String? comment}) => _decided('approve:${comment ?? ''}', TaskStatus.approved);

  @override
  Future<Result<Task>> reject(String taskId, {required String reason}) => _decided('reject:$reason', TaskStatus.rejected);

  @override
  Future<Result<Task>> requestCorrection(String taskId, {String? reason, required Map<String, String> requirements}) =>
      _decided('correction:$requirements', TaskStatus.correctionRequested);
}

void main() {
  const photo =
      SubmittedFile(id: 'e1', requirementId: 'r1', fileName: 'a.jpg', contentType: 'image/jpeg', sizeBytes: 1, uploaded: true);

  test('a photo URL is reused while fresh and asked again before it expires', () async {
    var now = DateTime.utc(2026, 10, 1, 9);
    final repository = _CountingRepository();
    final cubit = ReviewCubit(WatchTaskDetails(FakeTaskRepository([fakeTask('t1')])), repository,
        FakeDocumentOpener(), 't1', now: () => now);
    addTearDown(cubit.close);

    expect((await cubit.photoUrl(photo) as Ok<String>).value, 'http://files.test/1');
    now = now.add(const Duration(minutes: 5));
    expect((await cubit.photoUrl(photo) as Ok<String>).value, 'http://files.test/1');
    now = now.add(const Duration(minutes: 5));
    expect((await cubit.photoUrl(photo) as Ok<String>).value, 'http://files.test/2', reason: 'about to expire');

    cubit.forgetPhotoUrl(photo);
    expect((await cubit.photoUrl(photo) as Ok<String>).value, 'http://files.test/3', reason: 'after a failed load');
  });
}
