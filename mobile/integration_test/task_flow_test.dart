import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/main.dart' as app;

/// End to end on a device or emulator against a running backend: a worker
/// signs in, opens the task assigned to them, starts it, answers every
/// requirement and submits it; the backend then has the task as SUBMITTED
/// with the answers.
///
/// The administrator login (E2E_EMAIL / E2E_PASSWORD) only prepares the
/// data through the API: a new manager and worker, and a task with a
/// checkbox and a text requirement that the manager assigns to the worker.
/// Needs a fresh install (no saved session):
///
/// ```
/// flutter test integration_test/task_flow_test.dart \
///   --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...
/// ```
///
/// Skipped when no credentials are given (e.g. in CI without a backend).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const adminEmail = String.fromEnvironment('E2E_EMAIL');
  const adminPassword = String.fromEnvironment('E2E_PASSWORD');

  testWidgets(
    'worker completes and submits an assigned task',
    (tester) async {
      final api = _Api(AppConfig.fromEnvironment().apiBaseUrl);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final password = 'E2e-$stamp-pw';
      final admin = await api.login(adminEmail, adminPassword);
      await api.post('/api/users', admin, {
        'email': 'e2e.manager.$stamp@taskinspect.local',
        'fullName': 'E2E Manager',
        'password': password,
        'roles': ['MANAGER'],
      });
      final workerEmail = 'e2e.worker.$stamp@taskinspect.local';
      final worker = await api.post('/api/users', admin, {
        'email': workerEmail,
        'fullName': 'E2E Worker',
        'password': password,
        'roles': ['WORKER'],
      });
      final manager = await api.login('e2e.manager.$stamp@taskinspect.local', password);
      final title = 'E2E inspection $stamp';
      final task = await api.post('/api/tasks', manager, {
        'title': title,
        'priority': 'HIGH',
        'dueDate': DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
      });
      final taskId = task['id'] as String;
      await api.post('/api/tasks/$taskId/requirements', manager, {'title': 'Valve closed', 'type': 'CHECKBOX'});
      await api.post('/api/tasks/$taskId/requirements', manager, {'title': 'Condition notes', 'type': 'TEXT'});
      await api.post('/api/tasks/$taskId/assign', manager, {'assigneeId': worker['id']});

      await app.main();
      await _pumpUntil(tester, find.byKey(const Key('login-submit')));
      await tester.enterText(find.byKey(const Key('login-email')), workerEmail);
      await tester.enterText(find.byKey(const Key('login-password')), password);
      await tester.tap(find.byKey(const Key('login-submit')));
      await _pumpUntil(tester, find.text('Hello, E2E Worker'));

      // My tasks open on "Pending"; the task arrives with the first sync.
      await tester.tap(find.byTooltip('All tasks'));
      await _pumpUntil(tester, find.text(title), timeout: const Duration(seconds: 60));
      await tester.tap(find.text(title));
      await _pumpUntil(tester, find.byKey(const Key('start-task')));
      await tester.tap(find.byKey(const Key('start-task')));

      // Started: the requirements open one by one.
      await _pumpUntil(tester, find.byKey(const Key('checkbox-input')));
      expect(find.textContaining('Requirement 1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkbox-input')));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await _pumpUntil(tester, find.byKey(const Key('text-input')));
      await tester.enterText(find.byKey(const Key('text-input')), 'No leaks found');
      FocusManager.instance.primaryFocus?.unfocus();
      await _pumpUntil(tester, find.textContaining('2 answered'));
      expect(find.textContaining('Requirement 2 of 2 · 2 answered'), findsOneWidget);

      await tester.tap(find.byKey(const Key('submit-task')));
      await _pumpUntil(tester, find.text('Submit for review?'));
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Submit')));

      // Back on the task, which shows it as submitted.
      await _pumpUntil(tester, find.text('Submitted'));
      expect(find.byKey(const Key('submit-task')), findsNothing);
      expect(find.text('Submitted'), findsWidgets);

      // The sync brings the answers and the submit to the backend.
      Map<String, dynamic>? onServer;
      final end = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(end)) {
        onServer = await api.get('/api/tasks/$taskId', manager) as Map<String, dynamic>;
        if (onServer['status'] == 'SUBMITTED') {
          break;
        }
        await tester.pump(const Duration(seconds: 1));
      }
      expect(onServer?['status'], 'SUBMITTED');
      final responses = (await api.get('/api/tasks/$taskId/responses', manager) as List).cast<Map<String, dynamic>>();
      expect(responses.map((r) => r['booleanValue']), contains(true));
      expect(responses.map((r) => r['textValue']), contains('No leaks found'));
    },
    skip: adminEmail.isEmpty || adminPassword.isEmpty,
  );
}

/// The backend API, used only to prepare and check the test data.
class _Api {
  _Api(String baseUrl) : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  final Dio _dio;

  /// Signs in and returns the access token.
  Future<String> login(String email, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data!['accessToken'] as String;
  }

  Future<Map<String, dynamic>> post(String path, String token, Map<String, dynamic> body) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body, options: _auth(token));
    return response.data ?? const {};
  }

  Future<Object?> get(String path, String token) async {
    final response = await _dio.get<Object?>(path, options: _auth(token));
    return response.data;
  }

  Options _auth(String token) => Options(headers: {'Authorization': 'Bearer $token'});
}

/// Waits for a real network answer (pumpAndSettle can't see HTTP calls);
/// fails right there when it does not come, so the failing step is clear.
Future<void> _pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out after ${timeout.inSeconds} s waiting for ${finder.describeMatch(Plurality.many)}');
}
