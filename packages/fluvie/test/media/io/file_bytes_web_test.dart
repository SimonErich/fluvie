import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/media/io/file_bytes_web.dart';

void main() {
  test('the web file-bytes seam fails with a typed, source-naming error', () async {
    await expectLater(
      () => readFileBytes('/some/local/photo.png'),
      throwsA(
        isA<FluvieRenderException>()
            .having((e) => e.message, 'message', contains('/some/local/photo.png'))
            .having((e) => e.message, 'message', contains('not supported on web')),
      ),
    );
  });
}
