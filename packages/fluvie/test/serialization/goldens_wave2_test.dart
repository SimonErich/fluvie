// The wave-2 element goldens, spec-built: one composed scene per codec group
// (text family, media/chart, snapshot surfaces, wrappers+shared), each parsed
// from the same JSON an editor writes and pinned at a mid-scene frame so the
// reveals have visibly progressed. The snapshot surfaces (Mermaid, WebView,
// Html) paint deterministic in-process rasters carried by an
// ImageResolverScope — no browser, no network — mirroring the element goldens
// under test/elements/. Snapshot, Clip, Image, and Bars stay out: in capture
// they demand the render shell's pre-passes (subtree rasters, media, band
// tables) that a widget-test golden deliberately does not run.
@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/snapshot/snapshot_viewport.dart';
import 'package:fluvie/src/elements/mermaid/mermaid.dart';
import 'package:fluvie/src/elements/mermaid/mermaid_theme.dart';
import 'package:fluvie/src/elements/webview/html.dart';
import 'package:fluvie/src/elements/webview/webview.dart';
import 'package:fluvie/src/media/runtime/image_resolver_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

import '../rendering/fakes/fake_media_resolver.dart';

const _width = 480.0;
const _height = 270.0;

Map<String, Object?> _document(List<Map<String, Object?>> children, {String duration = '120f'}) => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'scenes': [
    {
      'duration': duration,
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#101018'},
      'children': children,
    },
  ],
};

/// The text family: plain and rich `Text`, a fully typed `Typewriter`, a
/// revealed `Markdown`, a settled `Counter`, and a decorated `Box` card.
Map<String, Object?> _textScene() => _document([
  {
    'type': 'Text',
    'text': 'Wave two',
    'textAlign': 'center',
    'style': {'fontSize': 34, 'color': '#F0F0F5', 'fontWeight': 'bold'},
    'transform': {'x': 0.5, 'y': 0.12, 'w': 0.9, 'h': 0.18},
  },
  {
    'type': 'Text',
    'spans': [
      {'text': 'Built with '},
      {
        'text': 'Fluvie',
        'link': 'https://fluvie.dev',
        'style': {'color': '#6C5CE7', 'fontWeight': 'bold'},
      },
    ],
    'style': {'fontSize': 16, 'color': '#B2BEC3'},
    'transform': {'x': 0.5, 'y': 0.28, 'w': 0.9, 'h': 0.12},
  },
  {
    'type': 'Box',
    'decoration': {
      'color': '#2D3436',
      'cornerRadius': 18,
      'border': {'color': '#6C5CE7', 'width': 2},
    },
    'transform': {'x': 0.22, 'y': 0.55, 'w': 0.32, 'h': 0.3},
  },
  {
    'type': 'Counter',
    'to': 4999,
    'variant': 'currency',
    'symbol': '€',
    'reveal': '45f',
    'style': {'fontSize': 22, 'color': '#F0D86A'},
    'transform': {'x': 0.22, 'y': 0.55, 'w': 0.3, 'h': 0.12},
  },
  {
    'type': 'Markdown',
    'source': '# Agenda\n\n- codecs',
    'reveal': '30f',
    'transform': {'x': 0.73, 'y': 0.6, 'w': 0.48, 'h': 0.5},
  },
  {
    'type': 'Typewriter',
    'text': 'typed one glyph at a time',
    'speed': '3f',
    'caret': true,
    'style': {'fontFamily': 'monospace', 'fontSize': 14, 'color': '#2ECC8F'},
    'transform': {'x': 0.5, 'y': 0.88, 'w': 0.9, 'h': 0.12},
  },
]);

/// Media and charts: a typed `Terminal` session, a `Code` snippet with focus
/// and highlight, and two `Chart` variants (revealed bars, a donut).
Map<String, Object?> _mediaScene() => _document(duration: '180f', [
  {
    'type': 'Terminal',
    'lines': [
      {'cmd': 'npm install', 'prompt': '>'},
      {'out': 'added 120 packages'},
    ],
    'prompt': r'$ ',
    'chrome': {'title': 'zsh'},
    'typingSpeed': '2f',
    'lineGap': '10f',
    'style': {'fontSize': 11},
    'transform': {'x': 0.26, 'y': 0.28, 'w': 0.46, 'h': 0.48},
  },
  {
    'type': 'Code',
    'source': "void main() {\n  print('hi');\n}",
    'language': 'dart',
    'theme': 'dark',
    'reveal': {'kind': 'typing', 'speed': '2f'},
    'focusLines': [2],
    'highlightLines': [2],
    'transform': {'x': 0.74, 'y': 0.28, 'w': 0.42, 'h': 0.48},
  },
  {
    'type': 'Chart',
    'variant': 'bar',
    'data': {'Jan': 30, 'Feb': 45, 'Mar': 28},
    'reveal': '45f',
    'stagger': {'each': '3f'},
    'transform': {'x': 0.26, 'y': 0.76, 'w': 0.42, 'h': 0.38},
  },
  {
    'type': 'Chart',
    'variant': 'donut',
    'data': {'Web': 52, 'Mobile': 48},
    'innerRadius': 0.4,
    'transform': {'x': 0.74, 'y': 0.76, 'w': 0.3, 'h': 0.38},
  },
]);

const _graph = 'graph TD; A-->B; B-->C;';
const _pricingUri = 'https://example.com/pricing';
const _banner = '<h1>Hello</h1>';
const _webViewport = SnapshotViewport(width: 640, height: 400);
const _htmlViewport = SnapshotViewport(width: 400, height: 100);

/// The snapshot surfaces: a `Mermaid` diagram, a `WebView` page, and an
/// inline `Html` banner, each painting a pre-resolved deterministic raster.
Map<String, Object?> _surfacesScene() => _document(duration: '90f', [
  {
    'type': 'Mermaid',
    'source': _graph,
    'theme': 'dark',
    'fit': 'contain',
    'transform': {'x': 0.25, 'y': 0.36, 'w': 0.42, 'h': 0.56},
  },
  {
    'type': 'WebView',
    'uri': _pricingUri,
    'viewport': {'width': 640, 'height': 400},
    'fit': 'cover',
    'transform': {'x': 0.74, 'y': 0.36, 'w': 0.44, 'h': 0.56},
  },
  {
    'type': 'Html',
    'source': _banner,
    'viewport': {'width': 400, 'height': 100},
    'transform': {'x': 0.5, 'y': 0.84, 'w': 0.86, 'h': 0.24},
  },
]);

/// Wrappers and shared ids: a browser `DeviceFrame` around a `Markdown`, a
/// `Callout` and a `Spotlight` each around a `Box` (one carrying a `shared`
/// hero id, paired with a matching hero in the adjacent scene — a shared id
/// in a single scene is a timing error by design), and a `LowerThird` in its
/// child-wrapping form. The golden frame sits inside scene 0.
Map<String, Object?> _wrappersScene() => {
  'fluvieSpec': 1,
  'size': {'width': 480, 'height': 270},
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'layout': 'canvas',
      'background': {'kind': 'color', 'color': '#101018'},
      'children': [
        {
          'type': 'DeviceFrame',
          'variant': 'browser',
          'url': 'https://fluvie.dev',
          'child': {
            'type': 'Markdown',
            'source': '# Fluvie\n\nDeclare the video.',
            'reveal': '20f',
            'animate': [
              {'preset': 'fadeIn', 'duration': '15f'},
            ],
          },
          'transform': {'x': 0.27, 'y': 0.42, 'w': 0.5, 'h': 0.72},
        },
        {
          'type': 'Callout',
          'label': 'Active users',
          'target': {'x': 40, 'y': 90},
          'labelAt': {'x': 100, 'y': 20},
          'color': '#6C5CE7',
          'child': {
            'type': 'Box',
            'decoration': {'color': '#1B1B24', 'cornerRadius': 14},
          },
          'transform': {'x': 0.76, 'y': 0.28, 'w': 0.42, 'h': 0.4},
        },
        {
          'type': 'Spotlight',
          'region': {'x': 20, 'y': 20, 'w': 90, 'h': 60},
          'reveal': '18f',
          'shared': 'hero',
          'child': {'type': 'Box', 'color': '#2ECC8F'},
          'transform': {'x': 0.76, 'y': 0.72, 'w': 0.42, 'h': 0.4},
        },
        {
          'type': 'LowerThird',
          'name': 'Fluvie',
          'title': 'Wrapper elements',
          'reveal': '12f',
          'color': '#E6483FA8',
          'child': {'type': 'Box', 'color': '#14141C'},
          'transform': {'x': 0.27, 'y': 0.84, 'w': 0.5, 'h': 0.28},
        },
      ],
    },
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'type': 'Box',
          'color': '#2ECC8F',
          'shared': 'hero',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.6, 'h': 0.6},
        },
      ],
    },
  ],
};

/// Mounts the spec-built video in capture mode at [frame]; [resolver]
/// pre-resolves the snapshot surfaces when the scene declares any.
Widget _mounted(Map<String, Object?> json, {required int frame, FakeMediaResolver? resolver}) {
  final video = SizedBox(
    width: _width,
    height: _height,
    child: VideoSpec.fromJson(json).build(),
  );
  return RenderModeContext(
    mode: RenderMode.capture,
    child: RenderControllerScope(
      controller: RenderController(initialFrame: frame),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: resolver == null ? video : ImageResolverScope(resolver: resolver, child: video),
      ),
    ),
  );
}

/// A deterministic stand-in raster: a [base]-tinted page with a [accent]
/// header band and three content blocks — recognisable surface pixels with no
/// browser and no network.
Future<ui.Image> _raster(int width, int height, ui.Color base, ui.Color accent) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final w = width.toDouble();
  final h = height.toDouble();
  canvas
    ..drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = base)
    ..drawRect(ui.Rect.fromLTWH(0, 0, w, h * 0.22), ui.Paint()..color = accent);
  final block = ui.Paint()..color = const ui.Color(0xFF636E72);
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(ui.Rect.fromLTWH(w * 0.08, h * (0.34 + i * 0.2), w * 0.84, h * 0.12), block);
  }
  return recorder.endRecording().toImage(width, height);
}

Future<void> main() async {
  // The resolver answers the exact snapshot sources the spec-built widgets
  // compute, so the keys are taken from identically declared twins.
  const mermaidTwin = Mermaid(_graph, theme: MermaidTheme.dark());
  final webViewTwin = WebView.url(_pricingUri, viewport: _webViewport);
  const htmlTwin = Html(_banner, viewport: _htmlViewport);
  final resolver = FakeMediaResolver(
    {},
    snapshots: {
      mermaidTwin.snapshotSource!: await _raster(
        180,
        170,
        const ui.Color(0xFF1E1E28),
        const ui.Color(0xFF6C5CE7),
      ),
      webViewTwin.snapshotSource!: await _raster(
        _webViewport.width,
        _webViewport.height,
        const ui.Color(0xFFF4F6F8),
        const ui.Color(0xFF2D89EF),
      ),
      htmlTwin.snapshotSource!: await _raster(
        _htmlViewport.width,
        _htmlViewport.height,
        const ui.Color(0xFFE8F8F0),
        const ui.Color(0xFF2ECC8F),
      ),
    },
  );
  await resolver.preResolveAll(const []);

  await goldenTest(
    'the text family paints from the spec at a revealed frame',
    fileName: 'wave2_text_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'text family', child: _mounted(_textScene(), frame: 100)),
      ],
    ),
  );

  await goldenTest(
    'terminal, code, and charts paint from the spec at a revealed frame',
    fileName: 'wave2_media_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'media and charts', child: _mounted(_mediaScene(), frame: 160)),
      ],
    ),
  );

  await goldenTest(
    'the snapshot surfaces paint their pre-resolved rasters from the spec',
    fileName: 'wave2_surfaces_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(
          name: 'snapshot surfaces',
          child: _mounted(_surfacesScene(), frame: 80, resolver: resolver),
        ),
      ],
    ),
  );

  await goldenTest(
    'the wrapper elements paint their nested children from the spec',
    fileName: 'wave2_wrappers_scene',
    builder: () => GoldenTestGroup(
      columns: 1,
      children: [
        GoldenTestScenario(name: 'wrappers', child: _mounted(_wrappersScene(), frame: 70)),
      ],
    ),
  );
}
