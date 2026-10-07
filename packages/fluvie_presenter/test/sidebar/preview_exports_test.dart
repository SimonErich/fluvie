import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// The editor reuses the presenter's preview machinery, so the barrel must
/// expose it: the lazy capped cache, the hidden render host, and the
/// settled-frame widget.
void main() {
  test('the preview machinery is public API', () async {
    final service = SlidePreviewService(
      renderSlide: (slide) async => throw UnimplementedError('never rendered here'),
    );
    addTearDown(service.dispose);
    expect(service.capacity, 32);
    expect(service.peek(0), isA<ui.Image?>());
    expect(PreviewRenderHost, isNotNull);
    expect(SlidePreviewFrame, isNotNull);
    expect(slidePreviewServiceProvider, isNotNull);
  });
}
