// WI-11 (D-ResolvedSnapshot): the one sync-paint path Mermaid/WebView/Html
// share. With an ImageResolverScope above, capture paints a flutter.RawImage
// from decodedSnapshotFor; a capture WITHOUT a resolver throws a
// FluvieRenderException naming the source + the collect pass; a preview renders
// a documented placeholder (no live platform view). An opacity < 1 modulates
// the raster's alpha without a saveLayer (capture-safe).

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/snapshot/runtime/resolved_snapshot.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';

import '../../../rendering/fakes/fake_media_resolver.dart';

const _source = SnapshotSource.mermaid('graph TD; A-->B;');
const _viewport = SnapshotViewport(width: 320, height: 240);

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF3498DB),
  );
  return recorder.endRecording().toImage(4, 4);
}

Future<FakeMediaResolver> _resolverFor(SnapshotSource source, ui.Image image) async {
  final resolver = FakeMediaResolver(
    {},
    snapshots: {source: image},
  );
  await resolver.preResolveAll(const []);
  return resolver;
}

void main() {
  group('capture paint', () {
    testWidgets('paints a sync RawImage with the decoded snapshot and fit', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = await _resolverFor(_source, decoded);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: ResolvedSnapshot(source: _source, fit: BoxFit.fitWidth),
          ),
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.image, same(decoded));
      expect(raw.fit, BoxFit.fitWidth);
    });

    testWidgets('capture without a resolver throws naming the source and collect pass', (
      tester,
    ) async {
      await tester.pumpWidget(
        const RenderModeContext(
          mode: RenderMode.capture,
          child: ResolvedSnapshot(source: _source),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      final message = (error as FluvieRenderException).message;
      expect(message, contains('collectSnapshotSources'));
      expect(message, contains('mermaid'));
    });

    testWidgets('a url source error names the host source too', (tester) async {
      final urlSource = SnapshotSource.url(
        Uri.parse('https://example.com/p'),
        viewport: _viewport,
      );
      await tester.pumpWidget(
        RenderModeContext(
          mode: RenderMode.capture,
          child: ResolvedSnapshot(source: urlSource),
        ),
      );
      final error = tester.takeException();
      expect(error, isA<FluvieRenderException>());
      expect((error as FluvieRenderException).message, contains('example.com'));
    });
  });

  group('opacity', () {
    testWidgets('an opacity < 1 modulates the raster alpha (no saveLayer)', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = await _resolverFor(_source, decoded);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: ResolvedSnapshot(source: _source, opacity: 0.4),
          ),
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.colorBlendMode, BlendMode.modulate);
      expect(raw.color, isNotNull);
      expect(raw.color!.a, closeTo(0.4, 1e-6));
    });

    testWidgets('a full opacity applies no color modulation', (tester) async {
      final decoded = await _solidImage();
      addTearDown(decoded.dispose);
      final resolver = await _resolverFor(_source, decoded);

      await tester.pumpWidget(
        ImageResolverScope(
          resolver: resolver,
          child: const RenderModeContext(
            mode: RenderMode.capture,
            child: ResolvedSnapshot(source: _source),
          ),
        ),
      );

      final raw = tester.widget<flutter.RawImage>(find.byType(flutter.RawImage));
      expect(raw.color, isNull);
      expect(raw.colorBlendMode, isNull);
    });
  });

  group('preview placeholder (no scope)', () {
    testWidgets('preview without a scope renders the documented placeholder', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: ResolvedSnapshot(source: _source),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(flutter.RawImage), findsNothing);
      // The placeholder is a sized box, never a live platform view.
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}
