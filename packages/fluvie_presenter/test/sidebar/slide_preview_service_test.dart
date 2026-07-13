import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';

/// A fake renderer that resolves on demand, tracking concurrency.
final class _FakeRenderer {
  final List<int> rendered = [];
  final Map<int, Completer<ui.Image>> pending = {};
  int inFlight = 0;
  int maxInFlight = 0;

  Future<ui.Image> render(int slide) {
    rendered.add(slide);
    inFlight++;
    if (inFlight > maxInFlight) maxInFlight = inFlight;
    final completer = Completer<ui.Image>();
    pending[slide] = completer;
    return completer.future.whenComplete(() => inFlight--);
  }

  Future<void> complete(int slide) async {
    final image = await _pixel();
    pending.remove(slide)!.complete(image);
    // Let the awaiting service store the result.
    await Future<void>.delayed(Duration.zero);
  }

  static Future<ui.Image> _pixel() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    return recorder.endRecording().toImage(1, 1);
  }
}

void main() {
  test('renders once, then serves from the cache', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    expect(service.peek(0), isNull);

    final first = service.preview(0);
    await renderer.complete(0);
    final image = await first;
    expect(service.peek(0), same(image));

    final second = await service.preview(0);
    expect(second, same(image));
    expect(renderer.rendered, [0]);
  });

  test('notifies listeners when a preview lands', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    var notified = 0;
    service.addListener(() => notified++);
    final pending = service.preview(3);
    expect(notified, 0);
    await renderer.complete(3);
    await pending;
    expect(notified, 1);
  });

  test('deduplicates in-flight requests', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    final a = service.preview(1);
    final b = service.preview(1);
    await renderer.complete(1);
    expect(await a, same(await b));
    expect(renderer.rendered, [1]);
  });

  test('caps concurrent renders and drains the queue', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    final all = [for (var s = 0; s < 5; s++) service.preview(s)];
    await Future<void>.delayed(Duration.zero);
    expect(renderer.maxInFlight, 2);
    for (var s = 0; s < 5; s++) {
      await renderer.complete(s);
    }
    await Future.wait(all);
    expect(renderer.maxInFlight, 2);
    expect(renderer.rendered, hasLength(5));
  });

  test('evicts the least recently used preview at capacity', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render, capacity: 2);
    addTearDown(service.dispose);
    for (var s = 0; s < 2; s++) {
      final pending = service.preview(s);
      await renderer.complete(s);
      await pending;
    }
    // Touch 0 so slide 1 is the least recently used.
    expect(service.peek(0), isNotNull);
    final third = service.preview(2);
    await renderer.complete(2);
    await third;
    expect(service.peek(0), isNotNull);
    expect(service.peek(1), isNull);
    expect(service.peek(2), isNotNull);
  });

  test('invalidate clears the cache so previews regenerate', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    final pending = service.preview(0);
    await renderer.complete(0);
    await pending;
    service.invalidate();
    expect(service.peek(0), isNull);
    final again = service.preview(0);
    await renderer.complete(0);
    await again;
    expect(renderer.rendered, [0, 0]);
  });

  test('pregenerateAll warms every slide off the critical path', () async {
    final renderer = _FakeRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render, concurrency: 1);
    addTearDown(service.dispose);
    final warmup = service.pregenerateAll(3);
    for (var s = 0; s < 3; s++) {
      await renderer.complete(s);
    }
    await warmup;
    expect(renderer.rendered, [0, 1, 2]);
    expect(service.peek(0), isNotNull);
    expect(service.peek(2), isNotNull);
  });
}
