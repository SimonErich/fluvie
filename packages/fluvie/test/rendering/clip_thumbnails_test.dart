import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:mocktail/mocktail.dart';

class _Resolver extends Mock implements MediaResolver {}

void main() {
  setUpAll(() {
    registerFallbackValue(const MediaSource.asset('clip.mp4'));
    registerFallbackValue(<int>[]);
  });
  testWidgets('samples source endpoints and emits bounded PNGs from actual decoded frames', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(const ui.Color(0xffff0000), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(32, 32);
      picture.dispose();
      final resolver = _Resolver();
      const source = MediaSource.asset('clip.mp4');
      when(
        () => resolver.probeClip(any()),
      ).thenAnswer((_) async => (fps: 30.0, frameCount: 91, width: 32, height: 32, hasAudio: true));
      final frames = <int>[];
      when(
        () => resolver.preResolveClip(any(), any()),
      ).thenAnswer((i) async => frames.addAll(i.positionalArguments[1] as Iterable<int>));
      when(() => resolver.decodedClipFrame(any(), any())).thenReturn(image);
      final strip = await clipThumbnails(
        resolver: resolver,
        source: source,
        count: 4,
        width: 12,
        height: 8,
      );
      expect(frames, [0, 30, 60, 90]);
      expect(strip, hasLength(4));
      for (final bytes in strip) {
        final codec = await ui.instantiateImageCodec(bytes);
        final decoded = (await codec.getNextFrame()).image;
        expect((decoded.width, decoded.height), (12, 8));
        decoded.dispose();
        codec.dispose();
      }
      image.dispose();
    });
  });
}
