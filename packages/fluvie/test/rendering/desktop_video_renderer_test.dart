// DesktopVideoRenderer: the local-FFmpeg VideoRenderer. It wraps the existing
// capture path (the free `render`) and hands the manifest's argument array to
// an injected FfmpegRunner — no new engine, just the symmetric entry point the
// mobile and web renderers already have.

import 'dart:io';
import 'dart:typed_data';

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

DesktopVideoRenderer _renderer(
  WidgetTester tester,
  _RecordingRunner runner,
  Directory sandbox, {
  void Function(String message)? onWarning,
}) => DesktopVideoRenderer(
  pumpWidget: tester.pumpWidget,
  pumpFrame: () => tester.pump(),
  runner: runner,
  sandboxFactory: () async => sandbox,
  onWarning: onWarning,
);

void main() {
  testWidgets('complete request preserves exact canvas, output range and export policy', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(100, 80)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_request_');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });
    await tester.runAsync(
      () => _renderer(tester, runner, sandbox).renderRequest(
        VideoRenderRequest(
          composition: _title(),
          width: 100,
          height: 80,
          frameCount: 1,
          startFrame: 1,
          audio: false,
          warnOnDroppedAudio: false,
          export: const Export.mp4(crf: 19),
          posterFrame: 0,
        ),
      ),
    );
    expect(File('${sandbox.path}/frames.rgba').lengthSync(), 100 * 80 * 4);
    expect(runner.encodes.first, contains('100x80'));
    expect(runner.encodes.first[runner.encodes.first.indexOf('-crf') + 1], '19');
    expect(runner.encodes, hasLength(2));
  });

  testWidgets('renders a composition to an MP4 file through the runner', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_desktop_test_');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

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

  testWidgets('raw Video audio and authored encoder options survive host mounting', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_audio_delivery_');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });
    final video = Video(
      width: 32,
      height: 32,
      export: const Export.mp4(codec: ExportCodec.h265, crf: 21, preset: EncoderPreset.fast),
      audio: [
        Audio.musicSource(AudioSource.memory(Uint8List.fromList([1, 2, 3])), volume: 0.25),
      ],
      scenes: const [
        Scene(duration: Time.frames(2), children: [Text('hi')]),
      ],
    );
    await tester.runAsync(
      () => _renderer(tester, runner, sandbox).render(
        composition: video,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 66),
        longEdge: 32,
      ),
    );
    final args = runner.encodes.single;
    expect(args, contains('libx265'));
    expect(args[args.indexOf('-crf') + 1], '21');
    expect(args[args.indexOf('-preset') + 1], 'fast');
    expect(args[args.indexOf('-filter_complex') + 1], contains('volume=0.25'));
    expect(args, isNot(contains('-an')));
  });

  testWidgets('audio off on an audio-declaring Video warns once and stays silent', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_desktop_test_');
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    final warnings = <String>[];
    await tester.runAsync(() async {
      await _renderer(tester, runner, sandbox, onWarning: warnings.add).render(
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
    addTearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    final warnings = <String>[];
    await tester.runAsync(() async {
      await _renderer(tester, runner, sandbox, onWarning: warnings.add).render(
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

  testWidgets('capture cancellation removes the partial sandbox', (tester) async {
    _pinView(tester);
    final runner = _RecordingRunner();
    final sandbox = Directory.systemTemp.createTempSync('fluvie_cancel_render_');
    final token = RenderCancellation();
    Object? error;
    await tester.runAsync(() async {
      try {
        await DesktopVideoRenderer(
          pumpWidget: tester.pumpWidget,
          pumpFrame: () async {
            token.cancel();
            await tester.pump();
          },
          runner: runner,
          sandboxFactory: () async => sandbox,
          cancellation: token,
        ).render(
          composition: _title(),
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 66),
          longEdge: 32,
        );
      } on Object catch (caught) {
        error = caught;
      }
    });
    expect(error, isA<RenderCancelledException>());
    expect(sandbox.existsSync(), isFalse);
    expect(runner.encodes, isEmpty);
  });

  test('the contract is implementable from the barrels alone', () {
    const VideoRenderer<File>? desktop = null;
    expect(desktop, isNull);
  });
}
