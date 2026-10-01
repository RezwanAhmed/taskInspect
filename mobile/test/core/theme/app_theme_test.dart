import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskinspect/app.dart';
import 'package:taskinspect/core/theme/app_theme.dart';
import 'package:taskinspect/core/theme/status_colors.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_tasks.dart';

void main() {
  setUp(() => registerFakeTasks(FakeTaskRepository()));
  test('light and dark themes use Material 3 and the right brightness', () {
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.light.colorScheme.brightness, Brightness.light);
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
  });

  test('both themes provide status colors', () {
    expect(AppTheme.light.extension<StatusColors>(), StatusColors.light);
    expect(AppTheme.dark.extension<StatusColors>(), StatusColors.dark);
  });

  test('status colors blend smoothly between themes', () {
    final middle = StatusColors.light.lerp(StatusColors.dark, 0.5);
    expect(middle.approved, isNot(StatusColors.light.approved));
    expect(middle.approved, isNot(StatusColors.dark.approved));
  });

  testWidgets('app follows the device dark mode', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(TaskInspectApp(authBloc: authBlocWith(FakeAuthRepository())));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('to TaskInspect'));
    expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
  });
}
