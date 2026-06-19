import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_api/client.dart';
import 'package:fluvie_example/inspector/api_render_launcher.dart';
import 'package:fluvie_example/inspector/render_launcher.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiRenderClient extends Mock implements ApiRenderClient {}

void main() {
  setUpAll(() => registerFallbackValue(ApiRenderRequest.key('demo')));

  late _MockApiRenderClient client;
  late ApiRenderLauncher launcher;

  setUp(() {
    client = _MockApiRenderClient();
    launcher = ApiRenderLauncher(baseUrl: Uri.parse('https://render.test'), client: client);
  });

  test('returns the download URL and forwards progress on success', () async {
    when(() => client.renderAndWait(any(), onUpdate: any(named: 'onUpdate'))).thenAnswer((
      invocation,
    ) async {
      final onUpdate = invocation.namedArguments[#onUpdate] as void Function(RenderJobView)?;
      onUpdate?.call(const RenderJobView(id: 'rnd_1', status: 'running', completed: 6, total: 12));
      return RenderJobView(
        id: 'rnd_1',
        status: 'succeeded',
        video: FileLink(downloadUrl: Uri.parse('https://render.test/v1/files/rnd_1/video')),
      );
    });
    final progress = <RenderProgress>[];

    final result = await launcher.render('demo', onProgress: progress.add);

    expect(result.exitCode, 0);
    expect(result.downloadUrl, 'https://render.test/v1/files/rnd_1/video');
    expect(progress, [const RenderProgress(completed: 6, total: 12)]);
  });

  test('maps an ApiClientException to a failed result', () async {
    when(
      () => client.renderAndWait(any(), onUpdate: any(named: 'onUpdate')),
    ).thenThrow(const ApiClientException('server is busy', statusCode: 503));

    final result = await launcher.render('demo');

    expect(result.exitCode, 1);
    expect(result.stderr, 'server is busy');
  });
}
