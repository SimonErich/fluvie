import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:slides/editor/audio_preview_controller.dart';
import 'package:slides/editor/audio_preview_platform.dart';

final class FakeOutput implements AudioPreviewPlatform {
  final List<Uint8List> played = [];
  final List<AudioSource> sources = [];
  int decoded = 0;
  int stopped = 0;
  bool disposed = false;
  StateError? failure;
  Completer<PcmAudio>? decodeGate;
  Completer<void>? playing;
  @override
  Future<PcmAudio> decode(
    AudioSource source, {
    Uint8List? bytes,
    MediaResolver? resolver,
    NetworkAllowlist? allowlist,
  }) async {
    decoded++;
    sources.add(source);
    if (decodeGate != null) return decodeGate!.future;
    if (failure != null) throw failure!;
    return (samples: Float64List.fromList(List.filled(200, 0.25)), sampleRate: 100);
  }

  @override
  void unlock() {}
  @override
  Future<void> play(Uint8List wav, {double offsetSeconds = 0}) {
    played.add(wav);
    playing = Completer<void>();
    return playing!.future;
  }

  @override
  Future<void> stop() async {
    stopped++;
    if (playing != null && !playing!.isCompleted) playing!.complete();
    playing = null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

final class ClipProbeResolver implements MediaResolver {
  final List<MediaSource> prepared = [];
  final List<MediaSource> probed = [];
  bool hasAudio = true;
  StateError? failure;
  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async => prepared.addAll(sources);
  @override
  Future<ClipMetadata> probeClip(MediaSource source) async {
    if (!prepared.contains(source)) throw StateError('Source must be resolved before probing');
    probed.add(source);
    if (failure != null) throw failure!;
    return (fps: 59.94, frameCount: 300, width: 32, height: 18, hasAudio: hasAudio);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EditorDocument clipDoc() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'fps': 30,
  'lanes': [
    {'id': 'picture', 'kind': 'video', 'gain': 0.4},
  ],
  'scenes': [
    {
      'duration': '90f',
      'children': [
        {
          'id': 'clip',
          'type': 'Clip',
          'source': {'kind': 'file', 'value': '/movie.mp4'},
          'lane': 'picture',
          'show': {'from': '30f', 'to': '60f'},
          'trim': {'from': '30f', 'to': '150f'},
          'speed': 2.0,
          'volume': 0.5,
        },
      ],
    },
  ],
});

EditorDocument doc() => EditorDocument.fromJson(const {
  'fluvieSpec': 1,
  'fps': 30,
  'lanes': [
    {'id': 'one', 'kind': 'audio'},
    {'id': 'two', 'kind': 'audio', 'gain': 0.5},
  ],
  'audio': [
    {
      'kind': 'music',
      'source': {'kind': 'file', 'value': '/one.wav'},
      'lane': 'one',
    },
    {
      'kind': 'music',
      'source': {'kind': 'file', 'value': '/two.wav'},
      'lane': 'two',
    },
  ],
  'scenes': [
    {'duration': '60f', 'children': <Object?>[]},
  ],
});
Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('source audition completes, rejects decode failures and reports output failures', (
    tester,
  ) async {
    final monitor = AudioMonitorController();
    final output = FakeOutput();
    final bytes = Uint8List.fromList([1, 2, 3]);
    final controller = AudioPreviewController(
      monitor: monitor,
      platform: output,
      bytesFor: (key) => key == '/source.wav' ? bytes : null,
    );
    const source = MediaStoreEntry(
      id: 'source',
      name: 'source.wav',
      kind: MediaStoreKind.audio,
      source: {'kind': 'file', 'value': '/source.wav'},
      fps: 10,
    );
    await controller.audition(source, frame: 5);
    await flush(tester);
    expect(output.sources.single, isA<MemoryAudioSource>());
    expect(readPcmWav(output.played.single).samples.length, 33075);
    output.playing!.complete();
    await flush(tester);
    expect(controller.auditioning, isFalse);
    await controller.audition(source, frame: 100);
    await flush(tester);
    expect(controller.auditioning, isFalse);
    expect(output.played, hasLength(1));
    await controller.audition(source);
    await flush(tester);
    output.playing!.completeError(StateError('Output disconnected'));
    await flush(tester);
    expect(controller.error, contains('Output disconnected'));
    output.failure = StateError('Invalid source');
    await controller.audition(
      const MediaStoreEntry(
        id: 'bad',
        name: 'bad.wav',
        kind: MediaStoreKind.audio,
        source: {'kind': 'file', 'value': '/bad.wav'},
      ),
    );
    await flush(tester);
    expect(controller.error, contains('Invalid source'));
    expect(controller.auditioning, isFalse);
    expect(controller.loading, isFalse);
    controller.dispose();
    await flush(tester);
    monitor.dispose();
  });

  testWidgets('playing frame discontinuities and chunk boundaries restart from the visible clock', (
    tester,
  ) async {
    final monitor = AudioMonitorController();
    final output = FakeOutput();
    final controller = AudioPreviewController(monitor: monitor, platform: output);
    final transport = SlideTransport(fps: 30, length: 1800);
    final document = EditorDocument.fromJson({
      ...doc().toJson(),
      'scenes': const [
        {'duration': '1800f'},
      ],
    });
    controller
      ..updateDocument(document)
      ..bindTransport(transport);
    await flush(tester);
    transport.play();
    await flush(tester);
    expect(output.played, hasLength(1));
    for (var frame = 15; frame <= 900; frame += 15) {
      transport.controller.seek(frame);
    }
    await flush(tester);
    expect(
      output.played,
      hasLength(2),
      reason: 'The 30-second chunk advances without pausing the clock',
    );
    transport.controller.seek(30);
    await flush(tester);
    expect(output.played, hasLength(3), reason: 'A reverse seek cancels stale output');
    expect(readPcmWav(output.played.last).samples.first, closeTo(.375, .001));
    await controller.audition(
      const MediaStoreEntry(
        id: 'source',
        name: 'one.wav',
        kind: MediaStoreKind.audio,
        source: {'kind': 'file', 'value': '/one.wav'},
      ),
    );
    await flush(tester);
    expect(transport.isPlaying, isFalse);
    expect(controller.auditioning, isTrue);
    transport.play();
    await flush(tester);
    expect(controller.auditioning, isFalse);
    controller.dispose();
    await flush(tester);
    transport.dispose();
    monitor.dispose();
  });
  testWidgets(
    'program audition follows export lane gains, solo, pause, caching and undo identity',
    (tester) async {
      final monitor = AudioMonitorController();
      final output = FakeOutput();
      final controller = AudioPreviewController(monitor: monitor, platform: output);
      final transport = SlideTransport(fps: 30, length: 60);
      final document = doc();
      final digest = document.renderDigest;
      controller
        ..updateDocument(document)
        ..bindTransport(transport);
      await flush(tester);
      expect(controller.loading, isFalse);
      expect(controller.error, isNull);
      expect(controller.envelopes, hasLength(2));
      expect(output.decoded, 2);
      transport.play();
      await flush(tester);
      expect(readPcmWav(output.played.last).samples.first, closeTo(.375, 0.001));
      monitor.toggleSolo('two');
      await flush(tester);
      expect(readPcmWav(output.played.last).samples.first, closeTo(.125, 0.001));
      expect(document.renderDigest, digest);
      expect(output.decoded, 2);
      final plays = output.played.length;
      transport.pause();
      await flush(tester);
      expect(output.playing, isNull);
      expect(output.played.length, plays);
      controller.dispose();
      await flush(tester);
      expect(output.disposed, isTrue);
      transport.dispose();
      monitor.dispose();
    },
  );
  testWidgets('decode failures are visible and retry recovers; source stop cancels playback', (
    tester,
  ) async {
    final monitor = AudioMonitorController();
    final output = FakeOutput()..failure = StateError('No decoder');
    final controller = AudioPreviewController(monitor: monitor, platform: output)
      ..updateDocument(doc());
    await flush(tester);
    expect(controller.error, contains('No decoder'));
    expect(controller.loading, isFalse);
    output.failure = null;
    controller.retry();
    await flush(tester);
    expect(controller.error, isNull);
    await controller.audition(
      const MediaStoreEntry(
        id: 'source',
        name: 'one.wav',
        kind: MediaStoreKind.audio,
        source: {'kind': 'file', 'value': '/one.wav'},
      ),
      frame: 15,
    );
    await flush(tester);
    expect(controller.auditioning, isTrue);
    expect(readPcmWav(output.played.last).samples.length, 33075);
    controller.stopAudition();
    await flush(tester);
    expect(controller.auditioning, isFalse);
    expect(output.playing, isNull);
    controller.dispose();
    await flush(tester);
    monitor.dispose();
  });
  testWidgets('late decoding never restarts output after pause or document replacement', (
    tester,
  ) async {
    final monitor = AudioMonitorController();
    final output = FakeOutput()..decodeGate = Completer<PcmAudio>();
    final controller = AudioPreviewController(monitor: monitor, platform: output);
    final transport = SlideTransport(fps: 30, length: 60);
    controller
      ..updateDocument(doc())
      ..bindTransport(transport);
    transport.play();
    await flush(tester);
    transport.pause();
    output.decodeGate!.complete((
      samples: Float64List.fromList(List.filled(200, 0.25)),
      sampleRate: 100,
    ));
    await flush(tester);
    expect(output.played, isEmpty);
    expect(controller.loading, isFalse);
    controller.updateDocument(doc().updateVideo({'audio': <Object?>[]}));
    await flush(tester);
    transport.play();
    await flush(tester);
    expect(output.played, isEmpty);
    controller.dispose();
    await flush(tester);
    transport.dispose();
    monitor.dispose();
  });
  testWidgets(
    'embedded clip audition resolves session bytes before metadata and matches its lane mix',
    (tester) async {
      final output = FakeOutput();
      final resolver = ClipProbeResolver();
      final monitor = AudioMonitorController();
      final bytes = Uint8List.fromList([1, 2, 3]);
      final controller = AudioPreviewController(
        monitor: monitor,
        platform: output,
        mediaResolver: resolver,
        bytesFor: (key) => key == '/movie.mp4' ? bytes : null,
      );
      final transport = SlideTransport(fps: 30, length: 90, initialFrame: 30);
      final document = clipDoc();
      controller
        ..updateDocument(document)
        ..bindTransport(transport);
      await flush(tester);
      expect(controller.error, isNull);
      expect(resolver.probed, hasLength(1));
      expect(resolver.prepared.single, isA<MemorySource>());
      expect(output.sources.single, isA<MemoryAudioSource>());
      expect(controller.clipMetadata['/movie.mp4']!.fps, 59.94);
      expect(controller.envelopes.keys, contains('/movie.mp4'));
      transport.play();
      await flush(tester);
      final mixed = readPcmWav(output.played.last);
      expect(mixed.samples.first, closeTo(0.05, 0.001));
      expect(mixed.samples.last, 0);
      final reads = resolver.probed.length;
      controller.updateDocument(document);
      await flush(tester);
      expect(resolver.probed, hasLength(reads));
      controller.dispose();
      await flush(tester);
      transport.dispose();
      monitor.dispose();
    },
  );

  testWidgets('embedded clip probe failure is retryable and silent clips do not decode audio', (
    tester,
  ) async {
    final output = FakeOutput();
    final resolver = ClipProbeResolver()..failure = StateError('Probe offline');
    final monitor = AudioMonitorController();
    final controller = AudioPreviewController(
      monitor: monitor,
      platform: output,
      mediaResolver: resolver,
    )..updateDocument(clipDoc());
    await flush(tester);
    expect(controller.error, contains('Probe offline'));
    expect(output.decoded, 0);
    resolver
      ..failure = null
      ..hasAudio = false;
    controller.retry();
    await flush(tester);
    expect(controller.error, isNull);
    expect(controller.clipMetadata['/movie.mp4']!.hasAudio, isFalse);
    expect(output.decoded, 0);
    expect(controller.loading, isFalse);
    controller.dispose();
    await flush(tester);
    monitor.dispose();
  });
}
