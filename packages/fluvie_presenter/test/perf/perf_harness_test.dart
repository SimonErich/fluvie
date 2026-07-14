// The phase-7 performance pass: measured, repeatable numbers for compile
// throughput, preview generation, stepping cost, and the preview-cache memory
// bound on a deliberately heavy deck. Tagged `render` so the default suite
// skips it; run with:
//   flutter test --tags render test/perf/perf_harness_test.dart
// Bounds are deliberately generous (CI-safe); the printed numbers are the
// point — they land in PROGRESS.md.
@Tags(['render'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';
import 'package:fluvie_presenter/src/shell/presenter_shell.dart';
import 'package:fluvie_presenter/src/sidebar/preview_render_host.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';

Video _heavyDeck({required int slides, int stops = 4}) => Video(
  width: 640,
  height: 360,
  scenes: [
    for (var s = 0; s < slides; s++)
      Scene(
        duration: const Time.seconds(2),
        background: Background.color(const Color(0xFF102030)),
        children: [
          Text('slide $s', style: const TextStyle(fontSize: 32, color: Color(0xFFFFFFFF))),
          for (var i = 0; i < stops; i++)
            Stop.single(
              child: Text(
                'point $i of slide $s',
                style: const TextStyle(fontSize: 18, color: Color(0xFFB0C4DE)),
              ),
            ),
        ],
      ),
  ],
);

void _report(String line) => stderr.writeln('[perf] $line');

void main() {
  test('compiling a 60-slide, 240-stop deck is fast', () {
    final video = _heavyDeck(slides: 60);
    final watch = Stopwatch()..start();
    final plans = compileSlidePlans(video);
    final compileMs = watch.elapsedMilliseconds;
    watch.reset();
    final notes = compileNotes(video, plans);
    final notesMs = watch.elapsedMilliseconds;
    _report('compileSlidePlans(60 slides x 4 stops): ${compileMs}ms');
    _report('compileNotes(60 slides): ${notesMs}ms');
    expect(plans, hasLength(60));
    expect(notes, hasLength(60));
    expect(compileMs, lessThan(2000));
    expect(notesMs, lessThan(2000));
  });

  testWidgets('preview generation throughput on the hidden host', (tester) async {
    const slides = 20;
    final video = _heavyDeck(slides: slides, stops: 2);
    final hostKey = GlobalKey<PreviewRenderHostState>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: PreviewRenderHost(key: hostKey, video: video, plans: compileSlidePlans(video)),
            ),
          ],
        ),
      ),
    );
    final watch = Stopwatch()..start();
    for (var s = 0; s < slides; s++) {
      final pending = hostKey.currentState!.render(s);
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      final image = await tester.runAsync(() => pending);
      // The host renders at its thumbnail width, not deck resolution.
      expect(image!.width, 320);
    }
    watch.stop();
    final perPreview = watch.elapsedMilliseconds / slides;
    _report(
      'preview generation: $slides previews in ${watch.elapsedMilliseconds}ms '
      '(${perPreview.toStringAsFixed(1)}ms each, software rendering)',
    );
    // A podium machine needs the sidebar to fill within seconds, not minutes.
    expect(perPreview, lessThan(1000));
  });

  testWidgets('stepping stays cheap across a heavy deck', (tester) async {
    final video = _heavyDeck(slides: 24);
    final container = ProviderContainer(
      overrides: [slidePlansProvider.overrideWithValue(compileSlidePlans(video))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(width: 800, height: 600, child: PresenterShell(video: video)),
          ),
        ),
      ),
    );
    await tester.pump();
    final controller = container.read(presentationControllerProvider.notifier);
    const steps = 80;
    var totalUs = 0;
    var maxUs = 0;
    final watch = Stopwatch();
    for (var i = 0; i < steps; i++) {
      watch
        ..reset()
        ..start();
      controller.next();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      watch.stop();
      totalUs += watch.elapsedMicroseconds;
      if (watch.elapsedMicroseconds > maxUs) maxUs = watch.elapsedMicroseconds;
    }
    final avgMs = totalUs / steps / 1000;
    _report(
      'stepping: $steps advances (reveals + slide changes) avg '
      '${avgMs.toStringAsFixed(1)}ms, worst ${(maxUs / 1000).toStringAsFixed(1)}ms per '
      'two-frame pump',
    );
    // Two pumped frames of budget headroom on software rendering.
    expect(avgMs, lessThan(100));
    // Let the last transition blend finish before teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the preview cache stays capped under many slides', (tester) async {
    const slides = 100;
    const capacity = 32;
    Future<ui.Image> renderPixel(int slide) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 64, 36),
        ui.Paint()..color = const ui.Color(0xFF445566),
      );
      return recorder.endRecording().toImage(64, 36);
    }

    final rssBefore = ProcessInfo.currentRss;
    final service = SlidePreviewService(renderSlide: renderPixel);
    await tester.runAsync(() => service.pregenerateAll(slides));
    var cached = 0;
    for (var s = 0; s < slides; s++) {
      if (service.peek(s) != null) cached++;
    }
    final rssAfter = ProcessInfo.currentRss;
    _report(
      'preview cache: $slides slides pregenerated, $cached retained (cap $capacity), '
      'rss delta ${((rssAfter - rssBefore) / (1024 * 1024)).toStringAsFixed(1)}MB',
    );
    expect(cached, capacity);
  });
}
