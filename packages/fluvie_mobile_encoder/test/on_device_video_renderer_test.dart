import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_mobile_encoder/fluvie_mobile_encoder.dart';

/// A [CaptureHost] backed by the widget tester: it sizes the test view to the
/// render resolution and pumps real frames, so the orchestration exercises
/// Fluvie's true capture path without the engine-only off-screen host.
class _TesterCaptureHost implements CaptureHost {
  _TesterCaptureHost(this.tester, this.size);

  final WidgetTester tester;
  final Size size;
  bool disposed = false;

  @override
  Future<void> mount(Widget tree) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0;
    await tester.pumpWidget(tree);
  }

  @override
  Future<void> pumpFrame() => tester.pump();

  @override
  Future<void> dispose() async {
    disposed = true;
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  }
}

/// A capture host whose dispose throws after tearing down, to prove a cleanup
/// failure is reported through `onWarning` and never masks a finished render.
class _ThrowingDisposeHost extends _TesterCaptureHost {
  _ThrowingDisposeHost(super.tester, super.size);

  @override
  Future<void> dispose() async {
    await super.dispose();
    throw StateError('dispose boom');
  }
}

Directory _sandbox() {
  final dir = Directory.systemTemp.createTempSync('mob_render_');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

const Widget _composition = ColoredBox(color: Color(0xFF112233));

void main() {
  testWidgets('captures a composition and encodes it to out.mp4', (tester) async {
    final sandbox = _sandbox();
    final encoder = FakeMobileVideoEncoder();
    late _TesterCaptureHost host;
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => host = _TesterCaptureHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    final phases = <RenderPhase>[];
    final file = await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
        onProgress: (progress) => phases.add(progress.phase),
      ),
    );

    expect(file, isNotNull);
    expect(file!.path, endsWith('out.mp4'));
    expect(phases, [RenderPhase.capturing, RenderPhase.encoding, RenderPhase.complete]);
    expect(host.disposed, isTrue);
    expect(encoder.requests, hasLength(1));

    final req = encoder.requests.single;
    expect(req.width, 64);
    expect(req.height, 64);
    expect(req.fps, 30);
    expect(req.frameCount, 3);
    expect(req.codec, MobileVideoCodec.h264);
    expect(req.bitRate, defaultBitRate(width: 64, height: 64, fps: 30));
    expect(File(req.framesPath).existsSync(), isTrue);
    expect(File(req.framesPath).lengthSync(), 3 * 64 * 64 * 4);
  });

  testWidgets('honors an explicit bitrate and codec', (tester) async {
    final sandbox = _sandbox();
    final encoder = FakeMobileVideoEncoder();
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => _TesterCaptureHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
        codec: MobileVideoCodec.hevc,
        bitRate: 2500000,
      ),
    );

    final req = encoder.requests.single;
    expect(req.codec, MobileVideoCodec.hevc);
    expect(req.bitRate, 2500000);
  });

  testWidgets('writes the MP4 to an explicit outputFile', (tester) async {
    final sandbox = _sandbox();
    final dest = File('${sandbox.path}/custom_name.mp4');
    final encoder = FakeMobileVideoEncoder();
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => _TesterCaptureHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    final file = await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
        outputFile: dest,
      ),
    );

    expect(file!.path, dest.path);
    expect(encoder.requests.single.outputPath, dest.path);
  });

  testWidgets('a cleanup failure is reported, not masked, and the render succeeds', (tester) async {
    final messages = <String>[];
    final previous = OnDeviceVideoRenderer.onWarning;
    OnDeviceVideoRenderer.onWarning = messages.add;
    addTearDown(() => OnDeviceVideoRenderer.onWarning = previous);

    final sandbox = _sandbox();
    final renderer = OnDeviceVideoRenderer(
      encoder: FakeMobileVideoEncoder(),
      hostFactory: (size) => _ThrowingDisposeHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    final file = await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 100),
        longEdge: 64,
      ),
    );

    expect(file, isNotNull, reason: 'a cleanup hiccup must not fail a finished render');
    expect(messages.single, contains('Cleanup after render failed'));
    expect(messages.single, contains('dispose boom'));
  });

  testWidgets('rounds a sub-frame duration up to one frame', (tester) async {
    final sandbox = _sandbox();
    final encoder = FakeMobileVideoEncoder();
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => _TesterCaptureHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 1),
        longEdge: 64,
      ),
    );

    expect(encoder.requests.single.frameCount, 1);
  });

  testWidgets('defaults to a system-temp sandbox', (tester) async {
    final encoder = FakeMobileVideoEncoder();
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => _TesterCaptureHost(tester, size),
    );

    final file = await tester.runAsync(
      () => renderer.render(
        composition: _composition,
        aspect: Aspect.square,
        duration: const Duration(milliseconds: 67),
        longEdge: 64,
      ),
    );

    expect(file!.path, contains('fluvie_mobile_render_'));
    addTearDown(() => file.parent.deleteSync(recursive: true));
  });

  testWidgets('disposes the host and rethrows when the encoder fails', (tester) async {
    final sandbox = _sandbox();
    final encoder = FakeMobileVideoEncoder(
      throwOnEncode: const FluvieMobileEncoderException('boom'),
    );
    late _TesterCaptureHost host;
    final renderer = OnDeviceVideoRenderer(
      encoder: encoder,
      hostFactory: (size) => host = _TesterCaptureHost(tester, size),
      sandboxFactory: () async => sandbox,
    );

    await tester.runAsync(() async {
      await expectLater(
        renderer.render(
          composition: _composition,
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 100),
          longEdge: 64,
        ),
        throwsA(isA<FluvieMobileEncoderException>()),
      );
    });

    expect(host.disposed, isTrue);
  });

  test('rejects a non-positive fps', () {
    final renderer = OnDeviceVideoRenderer(encoder: FakeMobileVideoEncoder());
    expect(
      renderer.render(
        composition: const SizedBox(),
        aspect: Aspect.square,
        duration: const Duration(seconds: 1),
        fps: 0,
      ),
      throwsArgumentError,
    );
  });

  test('rejects a non-positive duration', () {
    final renderer = OnDeviceVideoRenderer(encoder: FakeMobileVideoEncoder());
    expect(
      renderer.render(
        composition: const SizedBox(),
        aspect: Aspect.square,
        duration: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  group('audio', () {
    Video audioVideo({List<Audio> audio = const [Audio.music('audio/song.mp3')]}) => Video(
      size: VideoSize.square,
      audio: audio,
      scenes: [
        Scene(
          duration: 1.seconds,
          background: Background.gradient(const [Color(0xFF111111), Color(0xFF222222)]),
        ),
      ],
    );

    testWidgets('materializes, mixes, and muxes audio when opted in', (tester) async {
      final sandbox = _sandbox();
      final encoder = FakeMobileVideoEncoder();
      final materializer = _FakeMaterializer();
      final renderer = OnDeviceVideoRenderer(
        encoder: encoder,
        hostFactory: (size) => _TesterCaptureHost(tester, size),
        sandboxFactory: () async => sandbox,
        audioMaterializer: materializer,
      );

      await tester.runAsync(
        () => renderer.render(
          composition: audioVideo(),
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 100),
          longEdge: 64,
          audio: true,
        ),
      );

      expect(materializer.materialized, ['audio/song.mp3']);
      final req = encoder.requests.single;
      expect(req.audioTracks, hasLength(1));
      expect(req.audioTracks.single.path, '/materialized/audio/song.mp3');
      expect(req.audioMasterVolume, 1);
    });

    testWidgets('warns once when a Video has audio but audio is off', (tester) async {
      final messages = <String>[];
      final previous = OnDeviceVideoRenderer.onWarning;
      OnDeviceVideoRenderer.onWarning = messages.add;
      addTearDown(() => OnDeviceVideoRenderer.onWarning = previous);

      final encoder = FakeMobileVideoEncoder();
      final renderer = OnDeviceVideoRenderer(
        encoder: encoder,
        hostFactory: (size) => _TesterCaptureHost(tester, size),
        sandboxFactory: () async => _sandbox(),
      );

      await tester.runAsync(
        () => renderer.render(
          composition: audioVideo(),
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 100),
          longEdge: 64,
        ),
      );

      expect(messages, hasLength(1));
      expect(messages.single, contains('on-device audio is off'));
      expect(encoder.requests.single.audioTracks, isEmpty);
    });

    testWidgets('stays silent without warning when warnings are suppressed', (tester) async {
      final messages = <String>[];
      final previous = OnDeviceVideoRenderer.onWarning;
      OnDeviceVideoRenderer.onWarning = messages.add;
      addTearDown(() => OnDeviceVideoRenderer.onWarning = previous);

      final encoder = FakeMobileVideoEncoder();
      final renderer = OnDeviceVideoRenderer(
        encoder: encoder,
        hostFactory: (size) => _TesterCaptureHost(tester, size),
        sandboxFactory: () async => _sandbox(),
      );

      await tester.runAsync(
        () => renderer.render(
          composition: audioVideo(),
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 100),
          longEdge: 64,
          warnOnDroppedAudio: false,
        ),
      );

      expect(messages, isEmpty);
      expect(encoder.requests.single.audioTracks, isEmpty);
    });

    testWidgets('a Video with no audio neither warns nor adds tracks', (tester) async {
      final messages = <String>[];
      final previous = OnDeviceVideoRenderer.onWarning;
      OnDeviceVideoRenderer.onWarning = messages.add;
      addTearDown(() => OnDeviceVideoRenderer.onWarning = previous);

      final encoder = FakeMobileVideoEncoder();
      final renderer = OnDeviceVideoRenderer(
        encoder: encoder,
        hostFactory: (size) => _TesterCaptureHost(tester, size),
        sandboxFactory: () async => _sandbox(),
      );

      await tester.runAsync(
        () => renderer.render(
          composition: audioVideo(audio: const []),
          aspect: Aspect.square,
          duration: const Duration(milliseconds: 100),
          longEdge: 64,
          audio: true,
        ),
      );

      expect(messages, isEmpty);
      expect(encoder.requests.single.audioTracks, isEmpty);
    });
  });
}

/// Records each materialized source and returns a stable fake local path.
class _FakeMaterializer implements MobileAudioMaterializer {
  final List<String> materialized = [];

  @override
  Future<String> materialize(String source) async {
    materialized.add(source);
    return '/materialized/$source';
  }
}
