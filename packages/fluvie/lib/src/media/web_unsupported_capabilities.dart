part of 'web_image_media_resolver.dart';

mixin _UnsupportedWebCapabilities implements MediaResolver {
  @override
  Future<void> preResolveSnapshots(
    Iterable<SnapshotSource> sources,
    SnapshotService service,
  ) async {
    if (sources.isNotEmpty) _unsupported('Snapshot "${sources.first}"');
  }

  @override
  ui.Image decodedSnapshotFor(SnapshotSource source) => _unsupported('Snapshot "$source"');

  @override
  Future<void> preResolveAudio(Iterable<AudioSource> sources) async {
    if (sources.isNotEmpty) _unsupported('Audio "${sources.first}"');
  }

  @override
  String materializedAudioPathFor(AudioSource source) => _unsupported('Audio "$source"');

  @override
  Future<void> preResolveReactive(
    Iterable<AudioSource> sources, {
    required BeatDetectionService beatDetector,
    required FrequencyAnalyzer analyzer,
    required int fps,
    required int totalFrames,
  }) async {
    if (sources.isNotEmpty) _unsupported('Reactive audio "${sources.first}"');
  }

  @override
  BeatGrid beatGridFor(AudioSource source) => _unsupported('Beat grid for "$source"');

  @override
  BandTable bandTableFor(AudioSource source) => _unsupported('Band table for "$source"');

  @override
  Future<void> preResolveCaptions(CaptionSource source) async => _unsupported('Captions "$source"');

  @override
  List<CaptionCue> cuesFor(CaptionSource source) => _unsupported('Captions "$source"');

  /// Fails with the shared "images only on web" message naming [what].
  Never _unsupported(String what) => throw FluvieCapabilityException(
    capability: what,
    host: 'the built-in browser media resolver',
    remedy:
        'Images and clips use the browser decoder. Supply a resolver supporting this '
        'capability or use the native render host. Preview soundtrack playback uses a '
        'separate PreviewAudioController.',
  );
}
