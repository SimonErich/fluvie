import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:slides/editor/export_options.dart';

void main() {
  test('delivery choices survive one-run copy without mutating the document', () {
    final spec = VideoSpec.fromJson({
      'fluvieSpec': 1,
      'fps': 30,
      'size': {'width': 640, 'height': 360},
      'scenes': [
        {'duration': '1s'},
      ],
    });
    final before = spec.digest();
    final choice = ExportOptions.forSpec(spec).copyWith(
      codec: ExportCodec.h265,
      bitRate: 5000000,
      preset: EncoderPreset.fast,
      pixelFormat: ExportPixelFormat.yuv420p10le,
    );
    final render = choice.applyTo(spec);
    expect(spec.digest(), before);
    expect(render.export!.codec, ExportCodec.h265);
    expect(render.export!.bitRate, 5000000);
    expect(render.export!.pixelFormat, ExportPixelFormat.yuv420p10le);
    expect(ExportOptions.forSpec(render), choice);
    expect(choice.copyWith(crf: 21).bitRate, isNull);
    expect(choice.copyWith(crf: 21).crf, 21);
    expect(choice.copyWith(clearRateControl: true).bitRate, isNull);
  });
}
