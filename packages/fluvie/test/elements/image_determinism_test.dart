// WI-12 (D4): the Image capture path is deterministic — two pumps of the same
// pre-resolved subtree paint the identical decoded `ui.Image` with the same
// fit, the sync no-async-in-frame guarantee the renderer relies on.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/elements/image.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _asset = MediaSource.asset('fixtures/swatch.png');

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFFE67E22),
  );
  return recorder.endRecording().toImage(4, 4);
}

void main() {
  testWidgets('two pumps paint the identical decoded image and fit', (tester) async {
    final decoded = await _solidImage();
    addTearDown(decoded.dispose);
    final resolver = FakeMediaResolver(
      {_asset: (bytes: Uint8List(0), contentHash: 'x')},
      images: {_asset: decoded},
    );
    await resolver.preResolveAll([_asset]);

    Widget subject() => ImageResolverScope(
      resolver: resolver,
      child: RenderModeContext(
        mode: RenderMode.capture,
        child: Image.asset('fixtures/swatch.png', fit: BoxFit.cover),
      ),
    );

    await tester.pumpWidget(subject());
    final first = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
    await tester.pumpWidget(subject());
    final second = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));

    expect(first.image, same(second.image));
    expect(first.image, same(decoded));
    expect(first.fit, second.fit);
    expect(first.fit, BoxFit.cover);
  });
}
