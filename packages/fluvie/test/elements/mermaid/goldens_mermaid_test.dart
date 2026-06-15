// WI-13 (D-Mermaid/D-Raster/D20): the Mermaid goldens. The diagram raster is
// produced IN-PROCESS by the MermaidSvgRasterizer from a hand-authored
// representative flowchart SVG (no Chromium, no network, fully deterministic),
// then carried down by an ImageResolverScope keyed by the Mermaid's own
// snapshotSource, so each golden shows real vector pixels:
//   * mermaid_flowchart  — the diagram at the final frame.
//   * mermaid_reveal      — the MermaidReveal.fadeNodes opacity ramp at
//                           0.3 / 0.7 / 1.0 of its window.
@Tags(['golden'])
library;

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/mermaid/mermaid.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_reveal.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_svg_rasterizer.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';

import '../../animation/helpers/golden_frame.dart';
import '../../rendering/fakes/fake_media_resolver.dart';

const _graph = 'graph TD; A-->B; B-->C; B-->D;';
const _canvas = Size(220, 200);

/// A small representative flowchart SVG (three boxes and connecting edges)
/// standing in for a real Mermaid render — laid out by hand so the golden is
/// deterministic and offline. Mermaid's headless layout would emit a richer SVG;
/// this is the same pixel step (`flutter_svg` rasterize) on a fixed string.
String _flowchartSvg() => [
  '<svg xmlns="http://www.w3.org/2000/svg" width="180" height="170" viewBox="0 0 180 170">',
  '<rect x="60" y="8" width="60" height="30" rx="6" fill="#2d2d2d" stroke="#9e9e9e"/>',
  '<line x1="90" y1="38" x2="90" y2="68" stroke="#9e9e9e" stroke-width="2"/>',
  '<rect x="60" y="68" width="60" height="30" rx="6" fill="#2d2d2d" stroke="#9e9e9e"/>',
  '<line x1="80" y1="98" x2="40" y2="128" stroke="#9e9e9e" stroke-width="2"/>',
  '<line x1="100" y1="98" x2="140" y2="128" stroke="#9e9e9e" stroke-width="2"/>',
  '<rect x="10" y="128" width="60" height="30" rx="6" fill="#2d2d2d" stroke="#9e9e9e"/>',
  '<rect x="110" y="128" width="60" height="30" rx="6" fill="#2d2d2d" stroke="#9e9e9e"/>',
  '</svg>',
].join();

Future<void> main() async {
  final raster = await const MermaidSvgRasterizer().rasterize(
    _flowchartSvg(),
    targetWidth: 180,
    targetHeight: 170,
  );
  // The diagram source is keyed by the Mermaid's own snapshotSource so the
  // resolver answers the exact source the widget paints from.
  const flowchart = Mermaid(_graph);
  const fading = Mermaid(_graph, reveal: MermaidReveal.fadeNodes(Time.frames(30)));
  final resolver = FakeMediaResolver(
    {},
    snapshots: {flowchart.snapshotSource!: raster},
  );
  await resolver.preResolveAll(const []);

  Widget scoped(Widget child) => ImageResolverScope(resolver: resolver, child: child);

  await goldenMotionFrames(
    description: 'Mermaid renders a flowchart raster at the final frame',
    fileName: 'mermaid_flowchart',
    frames: const [0],
    size: _canvas,
    subject: () => scoped(const Center(child: flowchart)),
  );

  await goldenMotionFrames(
    description: 'Mermaid fades its diagram in across the reveal window',
    fileName: 'mermaid_reveal',
    // 30-frame window: 9 ~= 0.3, 21 ~= 0.7, 30 = 1.0.
    frames: const [9, 21, 30],
    sceneFrames: 40,
    size: _canvas,
    subject: () => scoped(const Center(child: fading)),
  );
}
