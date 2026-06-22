import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';
import 'package:fluvie/src/core/contracts/snapshot_service.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/snapshot/snapshot_raster.dart';
import 'package:fluvie/src/core/snapshot/snapshot_request.dart';
import 'package:fluvie/src/rendering/no_media_resolver.dart';

/// A stub service the media-less resolver never actually invokes.
class _UnusedSnapshotService implements SnapshotService {
  @override
  Future<SnapshotRaster> rasterize(SnapshotRequest request) async =>
      SnapshotRaster(bytes: Uint8List(0), contentHash: 'x', width: 1, height: 1);
}

/// Beat/analysis services the media-less resolver must never reach: it throws
/// before delegating, so these fail loudly if it ever does.
class _UnusedBeats implements BeatDetectionService {
  @override
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

class _UnusedAnalyzer implements FrequencyAnalyzer {
  @override
  Future<BandTable> analyze(AudioSource source, {required int fps, required int totalFrames}) =>
      throw UnimplementedError();
}

void main() {
  group('NoMediaResolver', () {
    const resolver = NoMediaResolver();

    test('preResolveAll with no sources completes (media-less composition)', () async {
      await expectLater(resolver.preResolveAll(const []), completes);
    });

    test('preResolveAll with a source throws a FluvieRenderException naming MediaRepository', () {
      final source = MediaSource.network(Uri.parse('https://example.com/clip.mp4'));
      expect(
        () => resolver.preResolveAll([source]),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('MediaRepository'),
          ),
        ),
      );
    });

    test('resolvedFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.resolvedFor(const MediaSource.asset('logo.png')),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('MediaRepository'))
              .having((e) => e.message, 'message', contains('logo.png')),
        ),
      );
    });

    test('decodedImageFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.decodedImageFor(const MediaSource.asset('logo.png')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('logo.png')),
        ),
      );
    });

    test('probeClip throws a FluvieRenderException naming the clip source', () {
      expect(
        () => resolver.probeClip(const MediaSource.asset('clip.mp4')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('clip.mp4')),
        ),
      );
    });

    test('preResolveClip throws a FluvieRenderException naming the clip source', () {
      expect(
        () => resolver.preResolveClip(const MediaSource.asset('clip.mp4'), const [0, 1]),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('clip.mp4')),
        ),
      );
    });

    test('clipMetadataFor throws a FluvieRenderException naming the clip source', () {
      expect(
        () => resolver.clipMetadataFor(const MediaSource.asset('clip.mp4')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('clip.mp4')),
        ),
      );
    });

    test('decodedClipFrame throws a FluvieRenderException naming the frame and source', () {
      expect(
        () => resolver.decodedClipFrame(const MediaSource.asset('clip.mp4'), 7),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('clip.mp4'))
              .having((e) => e.message, 'message', contains('7')),
        ),
      );
    });

    test('preResolveSnapshots with no sources completes (snapshot-less)', () async {
      await expectLater(
        resolver.preResolveSnapshots(const [], _UnusedSnapshotService()),
        completes,
      );
    });

    test('preResolveSnapshots with a source throws naming MediaRepository', () {
      expect(
        () => resolver.preResolveSnapshots(
          const [SnapshotSource.mermaid('graph TD; A-->B')],
          _UnusedSnapshotService(),
        ),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('MediaRepository'),
          ),
        ),
      );
    });

    test('decodedSnapshotFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.decodedSnapshotFor(const SnapshotSource.mermaid('graph TD; A-->B')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('mermaid')),
        ),
      );
    });

    test('preResolveAudio with no sources completes (silent composition)', () async {
      await expectLater(resolver.preResolveAudio(const []), completes);
    });

    test('preResolveAudio with a source throws naming MediaRepository', () {
      expect(
        () => resolver.preResolveAudio(const [AudioSource.asset('song.mp3')]),
        throwsA(
          isA<FluvieRenderException>().having(
            (e) => e.message,
            'message',
            contains('MediaRepository'),
          ),
        ),
      );
    });

    test('materializedAudioPathFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.materializedAudioPathFor(const AudioSource.asset('song.mp3')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('song.mp3')),
        ),
      );
    });

    test('preResolveReactive with no sources completes without touching the services', () async {
      await expectLater(
        resolver.preResolveReactive(
          const [],
          beatDetector: _UnusedBeats(),
          analyzer: _UnusedAnalyzer(),
          fps: 30,
          totalFrames: 90,
        ),
        completes,
      );
    });

    test('preResolveReactive with a source throws naming MediaRepository, never delegating', () {
      expect(
        () => resolver.preResolveReactive(
          const [AudioSource.asset('beat.mp3')],
          beatDetector: _UnusedBeats(),
          analyzer: _UnusedAnalyzer(),
          fps: 30,
          totalFrames: 90,
        ),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('MediaRepository'))
              .having((e) => e.message, 'message', contains('beat.mp3')),
        ),
      );
    });

    test('beatGridFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.beatGridFor(const AudioSource.asset('beat.mp3')),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('beat grid'))
              .having((e) => e.message, 'message', contains('beat.mp3')),
        ),
      );
    });

    test('bandTableFor throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.bandTableFor(const AudioSource.asset('beat.mp3')),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('band table'))
              .having((e) => e.message, 'message', contains('beat.mp3')),
        ),
      );
    });

    test('preResolveCaptions throws a FluvieRenderException naming the source', () {
      expect(
        () => resolver.preResolveCaptions(const CaptionSource.srt('subs.srt')),
        throwsA(
          isA<FluvieRenderException>()
              .having((e) => e.message, 'message', contains('MediaRepository'))
              .having((e) => e.message, 'message', contains('subs.srt')),
        ),
      );
    });

    test('cuesFor throws a FluvieRenderException naming the caption source', () {
      expect(
        () => resolver.cuesFor(const CaptionSource.vtt('subs.vtt')),
        throwsA(
          isA<FluvieRenderException>().having((e) => e.message, 'message', contains('subs.vtt')),
        ),
      );
    });
  });
}
