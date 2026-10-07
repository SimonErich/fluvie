import 'dart:typed_data';

import 'package:flutter/widgets.dart' hide Animation, Clip, Image, Tween;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/audio/runtime/frame_list_beat_grid.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/rendering/capture/capture_shell.dart';

import 'fakes/fake_media_resolver.dart';

const _song = AudioSource.asset('assets/song.wav');
final _bands = BandTable({AudioBand.bass: Float64List(120)});
final _beats = FrameListBeatGrid([]);

class _Services implements BeatDetectionService, FrequencyAnalyzer {
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) =>
      throw StateError('The injected resolver serves prepared analysis.');

  @override
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames}) =>
      throw StateError('The injected resolver serves prepared analysis.');
}

class _LegacyResolver extends FakeMediaResolver {
  _LegacyResolver() : super(const {}, beatGrids: {_song: _beats}, bandTables: {_song: _bands});

  int preparations = 0;
  BeatDetectionService? detector;
  FrequencyAnalyzer? analyzer;
  List<AudioSource>? sources;
  (int, int)? clock;

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    preparations++;
    detector = beatDetector;
    this.analyzer = analyzer;
    this.sources = sources.toList();
    clock = (fps, totalFrames);
    await super.preResolveReactive(
      sources,
      beatDetector: beatDetector,
      analyzer: analyzer,
      fps: fps,
      totalFrames: totalFrames,
    );
  }
}

class _WindowResolver extends _LegacyResolver implements AudioWindowResolver {
  List<AudioAnalysisWindow>? windows;

  @override
  Future<void> preResolveAudioWindows(
    Iterable<AudioAnalysisWindow> windows, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
  }) async {
    this.windows = windows.toList();
    await preResolveReactive(
      windows.map((window) => window.source),
      beatDetector: beatDetector,
      analyzer: analyzer,
      fps: windows.first.fps,
      totalFrames: windows.first.endFrame,
    );
  }

  @override
  BeatGrid beatGridForWindow(AudioAnalysisWindow window) => _beats;

  @override
  BandTable bandTableForWindow(AudioAnalysisWindow window) => _bands;
}

Future<void> _prepare(WidgetTester tester, CompositionSession session) async {
  final controller = RenderController();
  addTearDown(controller.dispose);
  Widget tree() => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      width: 40,
      height: 40,
      child: buildCaptureShell(
        composition: session.mountTree(session.composition),
        boundaryKey: GlobalKey(),
        controller: controller,
      ).tree,
    ),
  );
  await session.prepare(
    mount: tester.pumpWidget,
    pump: () => tester.pump(),
    buildTree: tree,
    runAsync: tester.runAsync,
  );
}

void main() {
  for (final windowAware in [true, false]) {
    for (final injectServices in [true, false]) {
      testWidgets('prepares reactive audio once (windows=$windowAware, injected=$injectServices)', (
        tester,
      ) async {
        final resolver = windowAware ? _WindowResolver() : _LegacyResolver();
        final services = _Services();
        final session = CompositionSession(
          composition: Video(
            width: 40,
            height: 40,
            audio: [
              Audio.music(
                'assets/song.wav',
                at: Trigger.at(1.seconds),
                trim: 2.seconds.to(4.seconds),
                loop: true,
              ),
            ],
            scenes: [
              Scene(
                duration: 4.seconds,
                children: [
                  const SizedBox(width: 10, height: 10).animate([
                    Animation.pulse(on: AudioBand.bass, gain: 0.4),
                  ]),
                ],
              ),
            ],
          ),
          resolver: resolver,
          beatDetector: injectServices ? services : null,
          analyzer: injectServices ? services : null,
        );
        addTearDown(session.dispose);
        await _prepare(tester, session);
        await session.prepareResources(decodeImages: false, warmEffects: false);
        expect(resolver.preparations, 1);
        expect(resolver.sources, [_song]);
        expect(resolver.clock, (30, 120));
        expect(resolver.detector, injectServices ? same(services) : isA<BeatDetectionService>());
        expect(resolver.analyzer, injectServices ? same(services) : isA<FrequencyAnalyzer>());
        if (resolver is _WindowResolver) {
          expect(resolver.windows, [
            AudioAnalysisWindow(
              source: _song,
              sourceStart: const Duration(seconds: 2),
              sourceFrames: 60,
              startFrame: 30,
              endFrame: 120,
              fps: 30,
              loop: true,
            ),
          ]);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
