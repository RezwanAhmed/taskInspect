import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:taskinspect/core/config/app_config.dart';
import 'package:taskinspect/core/error/failure.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/core/network/api_client.dart';

void main() {
  late ApiClient client;
  late DioAdapter adapter;

  setUp(() {
    client = ApiClient.forConfig(AppConfig(environment: AppEnvironment.dev, apiBaseUrl: 'http://api.test'));
    adapter = DioAdapter(dio: client.dio);
  });

  Future<Result<String>> getTitle() => client.send(
        (dio) => dio.get<Object?>('/api/tasks/1'),
        (body) => (body! as Map<String, Object?>)['title']! as String,
      );

  test('uses the configured base URL and parses the body', () async {
    expect(client.dio.options.baseUrl, 'http://api.test');
    adapter.onGet('/api/tasks/1', (server) => server.reply(200, {'title': 'Kitchen'}));

    final result = await getTitle();

    expect(result, isA<Ok<String>>().having((ok) => ok.value, 'value', 'Kitchen'));
  });

  test('sends a request ID with every call', () async {
    String? sent;
    client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      sent = options.headers[RequestIdInterceptor.header] as String?;
      handler.next(options);
    }));
    adapter.onGet('/api/tasks/1', (server) => server.reply(200, {'title': 'Kitchen'}));

    await getTitle();

    expect(sent, matches(RegExp(r'^[0-9a-f]{32}$')));
  });

  test('backend error becomes a ServerFailure with code, message and request ID', () async {
    adapter.onGet('/api/tasks/1', (server) => server.reply(409, {
          'status': 409,
          'code': 'TASK_INVALID_TRANSITION',
          'message': 'Cannot approve a task in status IN_PROGRESS',
          'requestId': 'req-1',
        }));

    final failure = (await getTitle() as Err<String>).failure;

    expect(failure, isA<ServerFailure>()
        .having((f) => f.statusCode, 'status', 409)
        .having((f) => f.code, 'code', 'TASK_INVALID_TRANSITION')
        .having((f) => f.message, 'message', 'Cannot approve a task in status IN_PROGRESS')
        .having((f) => f.requestId, 'requestId', 'req-1'));
  });

  test('validation errors keep the failing fields', () async {
    adapter.onGet('/api/tasks/1', (server) => server.reply(400, {
          'code': 'VALIDATION_ERROR',
          'message': 'Request validation failed',
          'errors': [
            {'field': 'title', 'message': 'must not be blank'},
          ],
        }));

    final failure = (await getTitle() as Err<String>).failure as ServerFailure;

    expect(failure.fieldErrors, {'title': 'must not be blank'});
  });

  test('401 becomes an UnauthorizedFailure', () async {
    adapter.onGet('/api/tasks/1', (server) => server.reply(401, {'code': 'INVALID_TOKEN'}));

    final failure = (await getTitle() as Err<String>).failure;

    expect(failure, isA<UnauthorizedFailure>().having((f) => f.code, 'code', 'INVALID_TOKEN'));
  });

  test('connection problems become a NetworkFailure', () async {
    adapter.onGet(
      '/api/tasks/1',
      (server) => server.throws(
        0,
        DioException.connectionError(requestOptions: RequestOptions(path: '/api/tasks/1'), reason: 'offline'),
      ),
    );

    expect((await getTitle() as Err<String>).failure, isA<NetworkFailure>());
  });

  test('an unexpected body becomes an UnexpectedFailure', () async {
    adapter.onGet('/api/tasks/1', (server) => server.reply(200, ['not', 'an', 'object']));

    expect((await getTitle() as Err<String>).failure, isA<UnexpectedFailure>());
  });
}
