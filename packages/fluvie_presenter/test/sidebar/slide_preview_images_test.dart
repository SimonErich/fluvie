import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/src/sidebar/slide_preview_service.dart';

/// A renderer that hands out one fresh image per call and keeps every handle
/// it made, so a test can ask whether the service retired it.
final class _PixelRenderer {
  final List<ui.Image> produced = [];

  Future<ui.Image> render(int slide) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = ui.Color(0xFF000000 + slide),
    );
    final image = await recorder.endRecording().toImage(1, 1);
    produced.add(image);
    return image;
  }
}

void main() {
  test('evicting a preview releases its image', () async {
    final renderer = _PixelRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render, capacity: 2, concurrency: 1);
    addTearDown(service.dispose);

    for (var slide = 0; slide < 3; slide++) {
      await service.preview(slide);
    }

    expect(renderer.produced, hasLength(3));
    expect(renderer.produced[0].debugDisposed, isTrue, reason: 'the evicted preview is released');
    expect(renderer.produced[1].debugDisposed, isFalse);
    expect(renderer.produced[2].debugDisposed, isFalse);
  });

  test('invalidate releases every preview it drops', () async {
    final renderer = _PixelRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    await service.preview(0);
    await service.preview(1);

    service.invalidate();

    expect(renderer.produced, hasLength(2));
    expect(renderer.produced.every((image) => image.debugDisposed), isTrue);
  });

  test('dispose releases the cache it was holding', () async {
    final renderer = _PixelRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    await service.preview(0);

    service.dispose();

    expect(renderer.produced.single.debugDisposed, isTrue);
  });

  testWidgets('a preview already on screen survives the cache dropping it', (tester) async {
    final renderer = _PixelRenderer();
    final service = SlidePreviewService(renderSlide: renderer.render);
    addTearDown(service.dispose);
    final image = await tester.runAsync(() => service.preview(0));

    // A tile paints the borrowed handle; RawImage clones what it shows.
    await tester.pumpWidget(
      Center(
        child: SizedBox(width: 8, height: 8, child: RawImage(image: image)),
      ),
    );
    service.invalidate();
    await tester.pump();

    expect(
      renderer.produced.single.debugDisposed,
      isTrue,
      reason: 'the service releases the handle it owns',
    );
    expect(
      tester.renderObject<RenderImage>(find.byType(RawImage)).image!.debugDisposed,
      isFalse,
      reason: 'the tile keeps painting its own clone',
    );
  });
}
