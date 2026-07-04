import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';

/// An offline, ffmpeg-free [MediaResolver] for the lesson 05/06 goldens and the
/// determinism test (decision D16).
///
/// Images decode from the real committed fixtures; clip frames are served from
/// one solid synthesized [ui.Image] for every requested frame, so the resolver
/// answers deterministically without probing or extracting. It satisfies the
/// pre-resolution contract (everything is ready before frame 0) while keeping
/// the test hermetic and fast.
final class FakeLessonMedia implements MediaResolver {
  FakeLessonMedia._(this._images, this._clipFrame, this._clipMeta, this._sources);

  /// Builds a resolver that can answer for every source in [sources]: image
  /// sources are decoded from the asset bundle, clip sources share one solid
  /// frame at the canned [clipMetadata].
  static Future<FakeLessonMedia> create(
    Iterable<MediaSource> sources, {
    ClipMetadata clipMetadata = (fps: 30, frameCount: 30, width: 64, height: 64, hasAudio: false),
  }) async {
    final images = <MediaSource, ui.Image>{};
    final clipSources = <MediaSource>{};
    for (final source in sources) {
      if (_isClip(source)) {
        clipSources.add(source);
      } else {
        images[source] = await _decodeAsset(source);
      }
    }
    final clipFrame = await _solidImage(const ui.Color(0xFF2D7DD2));
    return FakeLessonMedia._(images, clipFrame, clipMetadata, {...sources, ...clipSources});
  }

  final Map<MediaSource, ui.Image> _images;
  final ui.Image _clipFrame;
  final ClipMetadata _clipMeta;
  final Set<MediaSource> _sources;
  bool _ready = false;

  @override
  Future<void> preResolveAll(Iterable<MediaSource> sources) async => _ready = true;

  @override
  Future<ClipMetadata> probeClip(MediaSource source) async => _clipMeta;

  @override
  Future<void> preResolveClip(MediaSource source, Iterable<int> sourceFrames) async =>
      _ready = true;

  @override
  ResolvedMedia resolvedFor(MediaSource source) =>
      (bytes: Uint8List(0), contentHash: source.hashCode.toRadixString(16));

  @override
  ui.Image decodedImageFor(MediaSource source) {
    _assertReady();
    final image = _images[source];
    if (image == null) throw StateError('FakeLessonMedia has no image for "$source".');
    return image;
  }

  @override
  ClipMetadata clipMetadataFor(MediaSource source) {
    _assertReady();
    return _clipMeta;
  }

  @override
  ui.Image decodedClipFrame(MediaSource source, int sourceFrame) {
    _assertReady();
    return _clipFrame;
  }

  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async => _ready = true;

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) =>
      throw StateError('FakeLessonMedia declares no snapshots.');

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async => _ready = true;

  @override
  String materializedAudioPathFor(AudioSource source) =>
      throw StateError('FakeLessonMedia declares no audio.');

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async => _ready = true;

  @override
  BeatGrid beatGridFor(AudioSource source) =>
      throw StateError('FakeLessonMedia declares no reactive audio.');

  @override
  BandTable bandTableFor(AudioSource source) =>
      throw StateError('FakeLessonMedia declares no reactive audio.');

  @override
  Future<void> preResolveCaptions(CaptionSource source) async => _ready = true;

  @override
  List<CaptionCue> cuesFor(CaptionSource source) =>
      throw StateError('FakeLessonMedia declares no captions.');

  void _assertReady() {
    if (!_ready) throw StateError('preResolveAll has not run.');
    assert(_sources.isNotEmpty, 'no sources declared');
  }

  static bool _isClip(MediaSource source) {
    final name = switch (source) {
      AssetSource(:final name) => name,
      FileSource(:final path) => path,
      NetworkSource(:final url) => url.path,
      MemorySource() => '',
    };
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm');
  }

  static Future<ui.Image> _decodeAsset(MediaSource source) async {
    final key = (source as AssetSource).name;
    final data = await rootBundle.load(key);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  static Future<ui.Image> _solidImage(ui.Color color) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 64, 64), ui.Paint()..color = color);
    return recorder.endRecording().toImage(64, 64);
  }
}
