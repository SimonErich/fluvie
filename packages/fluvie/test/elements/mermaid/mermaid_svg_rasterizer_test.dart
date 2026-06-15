import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_svg_rasterizer.dart';

const _square = '''
<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10" viewBox="0 0 20 10">
  <rect width="20" height="10" fill="#3366CC"/>
</svg>
''';

Future<List<int>> _rgba(ui.Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint8List();
}

void main() {
  group('MermaidSvgRasterizer', () {
    test('rasterizes an SVG string to a ui.Image at the viewBox size', () async {
      final image = await const MermaidSvgRasterizer().rasterize(_square);
      addTearDown(image.dispose);
      expect(image.width, 20);
      expect(image.height, 10);
    });

    test('the same SVG at the same size is byte-identical twice (determinism)', () async {
      const rasterizer = MermaidSvgRasterizer();
      final a = await rasterizer.rasterize(_square);
      addTearDown(a.dispose);
      final b = await rasterizer.rasterize(_square);
      addTearDown(b.dispose);
      expect(await _rgba(a), await _rgba(b));
    });

    test('a size override scales the raster', () async {
      final image = await const MermaidSvgRasterizer().rasterize(
        _square,
        targetWidth: 40,
        targetHeight: 20,
      );
      addTearDown(image.dispose);
      expect(image.width, 40);
      expect(image.height, 20);
    });

    test('invalid SVG throws a FluvieRenderException naming the failure', () {
      expect(
        () => const MermaidSvgRasterizer().rasterize('<svg this is not valid'),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('SVG'),
          ),
        ),
      );
    });

    test('empty SVG throws a FluvieRenderException', () {
      expect(
        () => const MermaidSvgRasterizer().rasterize(''),
        throwsA(isA<FluvieRenderException>()),
      );
    });
  });
}
