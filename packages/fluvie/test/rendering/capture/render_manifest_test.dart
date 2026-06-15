import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/rendering/capture/render_manifest.dart';

void main() {
  RenderManifest demo() => RenderManifest(
    width: 320,
    height: 240,
    fps: 30,
    frameCount: 48,
    framesFileName: 'frames.rgba',
    outputFileName: 'out.mp4',
    renderDigest: 'cbf29ce484222325',
    ffmpegArgs: const ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4'],
  );

  group('RenderManifest', () {
    test('round-trips through json', () {
      final manifest = demo();
      expect(RenderManifest.fromJson(manifest.toJson()), manifest);
    });

    test('toJson carries schemaVersion 1 first', () {
      expect(demo().toJson()['schemaVersion'], 1);
      expect(demo().toJson().keys.first, 'schemaVersion');
    });

    test('an unknown schemaVersion throws a FluvieRenderException', () {
      final json = demo().toJson()..['schemaVersion'] = 99;
      expect(
        () => RenderManifest.fromJson(json),
        throwsA(isA<FluvieRenderException>().having((e) => e.message, 'message', contains('99'))),
      );
    });

    test('the args list is preserved verbatim and unmodifiable', () {
      final manifest = RenderManifest.fromJson(demo().toJson());
      expect(manifest.ffmpegArgs, const ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.mp4']);
      expect(() => manifest.ffmpegArgs.add('boom'), throwsUnsupportedError);
    });

    test('value equality covers every field including the args', () {
      expect(demo(), demo());
      expect(demo().hashCode, demo().hashCode);

      final differentArgs = RenderManifest.fromJson(
        demo().toJson()..['ffmpegArgs'] = <Object?>['-i', 'frames.rgba', 'out.mp4'],
      );
      expect(demo(), isNot(equals(differentArgs)));
    });

    test('a manifest with no poster omits the poster fields from json', () {
      final json = demo().toJson();
      expect(json.containsKey('posterArgs'), isFalse);
      expect(json.containsKey('posterFileName'), isFalse);
      expect(demo().posterArgs, isNull);
      expect(demo().posterFileName, isNull);
    });

    RenderManifest withPoster() => RenderManifest(
      width: 320,
      height: 240,
      fps: 30,
      frameCount: 48,
      framesFileName: 'frames.rgba',
      outputFileName: 'out.gif',
      renderDigest: 'cbf29ce484222325',
      ffmpegArgs: const ['-f', 'rawvideo', '-i', 'frames.rgba', 'out.gif'],
      posterFileName: 'poster.png',
      posterArgs: const ['-f', 'rawvideo', '-i', 'frames.rgba', 'poster.png'],
    );

    test('a poster manifest round-trips the second invocation', () {
      final manifest = withPoster();
      expect(RenderManifest.fromJson(manifest.toJson()), manifest);
      expect(manifest.posterArgs, contains('poster.png'));
      expect(manifest.posterFileName, 'poster.png');
    });

    test('the poster args are unmodifiable', () {
      final manifest = RenderManifest.fromJson(withPoster().toJson());
      expect(() => manifest.posterArgs!.add('boom'), throwsUnsupportedError);
    });

    test('value equality covers the poster invocation', () {
      expect(withPoster(), withPoster());
      expect(withPoster(), isNot(demo()));
    });
  });
}
