import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

void main() {
  for (final export in const [
    Export.mp4(crf: 20),
    Export.mp4(preset: EncoderPreset.slow),
    Export.mp4(pixelFormat: ExportPixelFormat.yuv420p10le),
    Export.gif(),
  ]) {
    test(
      'refuses unsupported hardware options before allocating a capture host: $export',
      () async {
        final renderer = OnDeviceVideoRenderer(
          hostFactory: (_) => throw StateError('Must reject before capture'),
          sandboxFactory: () => throw StateError('Must reject before sandbox allocation'),
        );
        await expectLater(
          renderer.render(
            composition: DefaultAssetBundle(
              bundle: _Bundle(),
              child: Video(
                export: export,
                scenes: const [Scene(duration: Time.seconds(1))],
              ),
            ),
            aspect: Aspect.square,
            duration: const Duration(seconds: 1),
          ),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  }
}

class _Bundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);
}
