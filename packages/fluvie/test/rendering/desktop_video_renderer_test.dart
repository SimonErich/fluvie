// DesktopVideoRenderer: the local-FFmpeg VideoRenderer. It wraps the existing
// capture path (the free `render`) and hands the manifest's argument array to
// an injected FfmpegRunner — no new engine, just the symmetric entry point the
// mobile and web renderers already have.

import 'dart:io';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

/// Records every encode invocation and writes the output file the encode
/// would produce, so the returned [File] exists.
class _RecordingRunner implements FfmpegRunner {
  final List<List<String>> encodes = [];

  @override
  Future<FfmpegVersion?> probeVersion() async => null;

  @override
  Future<void> encode({required List<String> args, required Directory sandbox}) async {
    encodes.add(args);
    File('${sandbox.path}/out.mp4').writeAsBytesSync(const [0]);
  }
}

Video _title() => Video(
  width: 32,
  height: 32,
  scenes: const [
    Scene(duration: Time.frames(2), children: [Text('hi')]),
  ],
);

Video _withAudio() => Video(
  width: 32,
  height: 32,
  audio: const [Audio.music('beat.wav')],
  scenes: const [
    Scene(duration: Time.frames(2), children: [Text('hi')]),
  ],
);

/// Pins the tester's view to the render canvas so the capture shell lays out
/// at the exact size the config captures.
void _pinView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(32, 32)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

DesktopVideoRenderer _renderer(WidgetTester tester, _RecordingRunner runner, Directory sandbox) =>
    DesktopVideoRenderer(
      pumpWidget: tester.pumpWidget,
      pumpFrame: () => tester.pump(),
      runner: runner,
      sandboxFactory: () async => sandbox,
    );

void main() {
  testWidgets('renders a composition to an MP4 file through the runner', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_desktop_test_');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    final phases = <RenderPhase>[];
    late File out;
    await tester.runAsync(() async {
      out = await _renderer(tester, runner, sandbox).render(
        composition: _title(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 66),
        longEdge: 32,
        onProgress: (progress) => phases.add(progress.phase),
      );
    });

    expect(out.existsSync(), isTrue);
    expect(runner.encodes, hasLength(1));
    expect(runner.encodes.single, isNotEmpty, reason: 'the manifest argument array runs verbatim');
    expect(phases.first, RenderPhase.capturing);
    expect(phases, contains(RenderPhase.encoding));
    expect(phases.last, RenderPhase.complete);
  });

  testWidgets('audio off on an audio-declaring Video warns once and stays silent', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_desktop_test_');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    final warnings = <String>[];
    final previous = DesktopVideoRenderer.onWarning;
    DesktopVideoRenderer.onWarning = warnings.add;
    addTearDown(() => DesktopVideoRenderer.onWarning = previous);

    await tester.runAsync(() async {
      await _renderer(tester, runner, sandbox).render(
        composition: _withAudio(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 66),
        longEdge: 32,
        audio: false,
      );
    });

    expect(warnings, hasLength(1));
    expect(warnings.single, contains('audio'));
    expect(
      runner.encodes.single,
      contains('-an'),
      reason: 'the silent lane keeps the encoder on the no-audio plan',
    );
  });

  testWidgets('warnOnDroppedAudio false silences the dropped-audio warning', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_desktop_test_');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    final warnings = <String>[];
    final previous = DesktopVideoRenderer.onWarning;
    DesktopVideoRenderer.onWarning = warnings.add;
    addTearDown(() => DesktopVideoRenderer.onWarning = previous);

    await tester.runAsync(() async {
      await _renderer(tester, runner, sandbox).render(
        composition: _withAudio(),
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 66),
        longEdge: 32,
        audio: false,
        warnOnDroppedAudio: false,
      );
    });

    expect(warnings, isEmpty);
  });

  test('the contract is implementable from the barrels alone', () {
    const VideoRenderer<File>? desktop = null;
    expect(desktop, isNull);
  });
}
