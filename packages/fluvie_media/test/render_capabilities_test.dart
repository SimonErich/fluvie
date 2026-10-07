import 'package:fluvie_media/fluvie_media.dart';
import 'package:test/test.dart';

void main() {
  test('backend profiles retain their documented supported choices', () {
    expect(RenderCapabilities.mobile.supportsExport('gif'), isFalse);
    expect(RenderCapabilities.mobile.supportsExport('mp4'), isTrue);
    expect(RenderCapabilities.mobile.crf, isFalse);
    expect(RenderCapabilities.desktop.crf, isTrue);
    expect(RenderCapabilities.browser.exportModes, contains('transparent'));
  });

  test('the published capability registry is versioned and immutable', () {
    final json = RenderCapabilities.registryJson();
    expect(json['schemaVersion'], 1);
    expect((json['backends']! as List<Object?>).length, 3);
    expect(() => RenderCapabilities.mobile.videoCodecs.add('vp9'), throwsUnsupportedError);
    expect(RenderCapabilities.mobile.toJson()['evidence'], isNotEmpty);
  });
}
