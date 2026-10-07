import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_web_encoder/fluvie_web_encoder.dart';

void main() {
  test('local preview audio reports its browser requirement on native hosts', () async {
    expect(
      () => createLocalPreviewAudioController(
        endpoint: Uri.parse('http://127.0.0.1:1234'),
        sessionToken: 'session',
      ),
      throwsA(
        isA<UnsupportedError>().having((error) => error.message, 'platform', contains('browser')),
      ),
    );
    final controller = LocalPreviewAudioController();
    await expectLater(controller.activate(), throwsA(isA<UnsupportedError>()));
    await controller.synchronize(position: Duration.zero, playing: false, rate: 1);
    await controller.reload();
    await controller.dispose();
    await controller.dispose();
  });

  test('native reload subscriptions report the browser requirement without notifying callers', () {
    var reloaded = false;
    expect(
      () => watchLocalPreviewReloads(
        endpoint: Uri.parse('http://127.0.0.1:1234'),
        sessionToken: 'session',
        onReload: () => reloaded = true,
      ),
      throwsA(
        isA<UnsupportedError>().having((error) => error.message, 'platform', contains('browser')),
      ),
    );
    expect(reloaded, isFalse);
  });
}
