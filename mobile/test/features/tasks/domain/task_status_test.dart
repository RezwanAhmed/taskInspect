import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/core/theme/app_theme.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/domain/usecases/start_task.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/status_chip.dart';

import '../../../helpers/fake_tasks.dart';

void main() {
  test('every status the server sends is understood, including OPEN', () {
    for (final status in TaskStatus.values) {
      expect(TaskStatus.fromApi(status.apiName), status);
    }
    expect(TaskStatus.fromApi('OPEN'), TaskStatus.open);
  });

  test('nobody can start an open task before taking it', () {
    final open = fakeTask('1', status: TaskStatus.open);

    expect(StartTask.canStart(open, 'u1'), isFalse);
  });

  testWidgets('an open task shows an "Open" chip', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: StatusChip(TaskStatus.open)),
    ));

    expect(find.text('Open'), findsOneWidget);
  });
}
