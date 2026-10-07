import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' hide Clip;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';

class _EncodedRenderer implements VideoRenderer<File> {
  _EncodedRenderer(this.file);
  final File file;
  @override
  Future<File> render({
    required Widget composition,
    required Aspect aspect,
    required Duration duration,
    int fps = 30,
    int longEdge = 1920,
    bool audio = true,
    bool warnOnDroppedAudio = true,
    String compositionKey = 'render',
    RenderProgressCallback? onProgress,
  }) async => file;
}

class _RequestRenderer extends _EncodedRenderer implements RequestVideoRenderer<File> {
  _RequestRenderer(super.file);
  VideoRenderRequest? received;
  @override
  RenderCapabilities get capabilities => RenderCapabilities.desktop;
  @override
  Future<File> renderRequest(VideoRenderRequest request) async {
    received = request;
    return file;
  }
}

RenderHostContext _host(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return RenderHostContext(
    pumpWidget: tester.pumpWidget,
    pumpFrame: () => tester.pump(),
    runAsync: tester.runAsync,
    setViewSize: (w, h) {
      tester.view.physicalSize = Size(w.toDouble(), h.toDouble());
      tester.view.devicePixelRatio = 1;
    },
  );
}

Directory _workspace() {
  final workspace = Directory.systemTemp.createTempSync('fluvie_host_');
  addTearDown(() => workspace.deleteSync(recursive: true));
  return workspace;
}

Video _video() => Video(
  width: 16,
  height: 16,
  scenes: [
    Scene(
      duration: 3.frames,
      children: [
        FrameBuilder(
          (context) => SizedBox.expand(
            child: ColoredBox(
              color: context.frame == 0 ? const Color(0xffff0000) : const Color(0xff00ff00),
            ),
          ),
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('custom request renderer receives exact canvas and all authored overrides', (
    tester,
  ) async {
    final workspace = _workspace();
    final renderer = _RequestRenderer(
      File('${workspace.path}/custom.mp4')..writeAsStringSync('encoded'),
    );
    final video = Video(
      width: 100,
      height: 80,
      fps: 12,
      poster: 1.frames,
      export: const Export.mp4(crf: 19),
      scenes: [Scene(duration: 10.frames)],
    );
    final host = _host(tester);
    await runFluvieRender(
      video: video,
      host: host,
      invocation: RenderInvocation(outputDir: workspace.path, frameCount: 2, quality: Quality.low),
      rendererFactory: (_) => renderer,
    );
    final request = renderer.received!;
    expect((request.width, request.height, request.fps, request.frameCount), (100, 80, 12, 2));
    expect(request.export!.crf, 19);
    expect(request.export!.quality, Quality.low);
    expect(request.posterFrame, 1);
    expect(request.audio, isTrue);
    expect(request.cancellation, same(host.cancellation));
  });

  testWidgets('custom encoded renderer writes a receipt without capturing or re-encoding', (
    tester,
  ) async {
    final workspace = _workspace();
    final source = File('${workspace.path}/custom.mov')..writeAsStringSync('already encoded');
    await runFluvieRender(
      video: _video(),
      host: _host(tester),
      invocation: RenderInvocation(outputDir: workspace.path),
      rendererFactory: (host) {
        expect(host.video.fps, 30);
        return _EncodedRenderer(source);
      },
    );
    final result =
        jsonDecode(File('${workspace.path}/render-result.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(result['kind'], 'encoded');
    expect(File(result['filePath'] as String).readAsStringSync(), 'already encoded');
    expect(File('${workspace.path}/frames.rgba').existsSync(), isFalse);
  });

  testWidgets('inspect prepares a composition without capturing frames', (tester) async {
    final workspace = _workspace();
    await runFluvieRender(
      video: _video(),
      host: _host(tester),
      invocation: RenderInvocation(outputDir: workspace.path, operation: 'inspect'),
    );
    final info =
        jsonDecode(File('${workspace.path}/inspection.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(info['totalFrames'], 3);
    expect(info['width'], 16);
    expect(info['hasAudio'], isFalse);
    expect(File('${workspace.path}/frames.rgba').existsSync(), isFalse);
  });

  testWidgets('audio preparation emits a bounded silent WAV plan without frame capture', (
    tester,
  ) async {
    final workspace = _workspace();
    await runFluvieRender(
      video: _video(),
      host: _host(tester),
      invocation: RenderInvocation(outputDir: workspace.path, operation: 'audio'),
    );
    final info =
        jsonDecode(File('${workspace.path}/audio-mix.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(info['silent'], isTrue);
    expect(info['ffmpegArgs'], containsAll(['48000', 'pcm_s16le', 'audio.wav']));
    expect(File('${workspace.path}/frames.rgba').existsSync(), isFalse);
  });

  testWidgets('frame captures the exact requested position rather than frame zero', (tester) async {
    final workspace = _workspace();
    await runFluvieRender(
      video: _video(),
      host: _host(tester),
      invocation: RenderInvocation(outputDir: workspace.path, operation: 'frame', frameIndex: 2),
    );
    final bytes = File('${workspace.path}/frames.rgba').readAsBytesSync();
    expect(bytes.sublist(0, 4), [0, 255, 0, 255]);
    expect(File('${workspace.path}/frame.png').readAsBytesSync().take(8), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
  });
}
