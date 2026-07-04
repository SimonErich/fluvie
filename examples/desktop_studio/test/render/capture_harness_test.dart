// The self-contained capture harness, driven by the fluvie CLI via
// `flutter test --dart-define`. A plain `flutter test` run skips the render, so
// this file stays green in the normal suite. It uses only the public Fluvie API
// and is modeled on the harness `fluvie init` scaffolds. Everything outside the
// `--- compositions ---` blocks is byte-identical across the example apps
// (tool/test/example_harness_sync_test.dart pins it against drift).

import 'dart:io';

import 'package:alchemist/alchemist.dart' show loadFonts;
// --- compositions ---
import 'package:desktop_studio/render/templates.dart';
// --- end compositions ---
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

/// Every composition this project can render, keyed for `fluvie render <key>`.
final Map<String, Video Function()> compositions = <String, Video Function()>{
  // --- compositions ---
  for (final template in studioTemplates) template.key: template.build,
  // --- end compositions ---
};

const String _key = String.fromEnvironment('FLUVIE_RENDER_KEY');
const String _outDir = String.fromEnvironment('FLUVIE_RENDER_OUT_DIR');
const String _frames = String.fromEnvironment('FLUVIE_RENDER_FRAMES');
const String _noCache = String.fromEnvironment('FLUVIE_RENDER_NO_CACHE');
const String _list = String.fromEnvironment('FLUVIE_RENDER_LIST');
const String _format = String.fromEnvironment('FLUVIE_RENDER_FORMAT');

void main() {
  testWidgets('the capture harness renders the keyed composition', (tester) async {
    if (bool.tryParse(_list) ?? false) {
      stdout.writeln('fluvie-keys: ${compositions.keys.join(', ')}');
      return;
    }
    if (_key.isEmpty) {
      markTestSkipped('No FLUVIE_RENDER_KEY: this harness only runs under `fluvie render`.');
      return;
    }
    final build = compositions[_key];
    if (build == null) {
      stdout.writeln(
        'fluvie-unknown-key: Unknown render key "$_key". '
        'Known keys: ${compositions.keys.join(', ')}',
      );
      fail('Unknown render key "$_key".');
    }
    expect(_outDir, isNotEmpty, reason: 'FLUVIE_RENDER_OUT_DIR must point at the CLI sandbox');

    await loadFonts();

    final video = build();
    final width = video.width;
    final height = video.height;
    tester.view.physicalSize = Size(width.toDouble(), height.toDouble());
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = RenderController();
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RenderModeContext(
        mode: RenderMode.capture,
        child: RenderControllerScope(
          controller: controller,
          child: RepaintBoundary(
            key: boundaryKey,
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'Roboto'),
              child: Directionality(textDirection: TextDirection.ltr, child: video),
            ),
          ),
        ),
      ),
    );

    final noCache = bool.tryParse(_noCache) ?? false;
    final service = RenderService(
      capture: const RepaintBoundaryCaptureService(),
      cache: FrameCache(FrameCache.defaultRoot()),
    );
    await tester.runAsync(() async {
      await service.captureToDirectory(
        config: RenderConfig(
          width: width,
          height: height,
          fps: video.fps,
          frameCount: _frames.isEmpty ? video.totalFrames : int.parse(_frames),
          cacheEnabled: !noCache,
        ),
        outDir: Directory(_outDir),
        pump: (frame) async {
          controller.seek(frame);
          await tester.pump();
        },
        boundaryKey: boundaryKey,
        compositionKey: _key,
        export: _exportFor(_format),
      );
    });
  }, timeout: Timeout.none);
}

/// Maps a `--format` define to an `Export` (null is the mp4 default).
Export? _exportFor(String format) => switch (format) {
  '' || 'mp4' => null,
  'gif' => const Export.gif(),
  'imageSequence' => const Export.imageSequence(),
  'transparent' => const Export.transparent(),
  _ => throw ArgumentError.value(format, 'format', 'unknown export format'),
};
