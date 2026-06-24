import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_server_studio/services/server_render_service.dart';
import 'package:web_server_studio/submit/submit_state.dart';
import 'package:web_server_studio/submit/submit_view_model.dart';

class _FakeService implements ServerRenderService {
  _FakeService({this.result, this.throwError});

  final Uri? result;
  final ServerRenderException? throwError;
  Uri? lastBaseUrl;
  Map<String, Object?>? lastSpec;
  String? lastToken;

  @override
  Future<Uri> render({
    required Uri baseUrl,
    required Map<String, Object?> spec,
    String? apiToken,
    void Function(double progress)? onProgress,
  }) async {
    lastBaseUrl = baseUrl;
    lastSpec = spec;
    lastToken = apiToken;
    onProgress?.call(0.5);
    if (throwError != null) throw throwError!;
    return result ?? Uri.parse('https://render.example/out.mp4');
  }
}

ProviderContainer _container(ServerRenderService service) {
  final container = ProviderContainer(
    overrides: [serverRenderServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('submit renders the promo spec and ends in done with a URL', () async {
    final service = _FakeService(
      result: Uri.parse('https://render.example/kitten.mp4'),
    );
    final container = _container(service);

    await container.read(submitViewModelProvider.notifier).submit();
    final state = container.read(submitViewModelProvider);

    expect(state.status, SubmitStatus.done);
    expect(state.downloadUrl.toString(), 'https://render.example/kitten.mp4');
    expect(service.lastSpec, isNotNull);
    expect(service.lastBaseUrl, isNotNull);
  });

  test('an invalid server URL fails before any request', () async {
    final service = _FakeService();
    final container = _container(service);
    container.read(submitViewModelProvider.notifier).setServerUrl('not a url');

    await container.read(submitViewModelProvider.notifier).submit();
    final state = container.read(submitViewModelProvider);

    expect(state.status, SubmitStatus.failed);
    expect(state.error, contains('valid http'));
    expect(service.lastBaseUrl, isNull);
  });

  test('an auth failure surfaces the auth message', () async {
    final service = _FakeService(
      throwError: const ServerRenderException(
        'The server rejected your API token. Check it and try again.',
        kind: ServerRenderErrorKind.auth,
      ),
    );
    final container = _container(service);

    await container.read(submitViewModelProvider.notifier).submit();
    final state = container.read(submitViewModelProvider);

    expect(state.status, SubmitStatus.failed);
    expect(state.error, contains('API token'));
  });
}
