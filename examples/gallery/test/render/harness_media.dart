import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
// The media wiring the harness needs is the real, ffmpeg-backed pipeline; it
// lives under `src/` because pre-resolution is render infrastructure, not part
// of the authoring surface a lesson imports. `SnapshotSource` is render
// infrastructure too, off the authoring barrel.
import 'package:fluvie/src/core/captions/caption_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';
import 'package:fluvie_example/lessons/lessons.dart';
import 'package:fluvie_example/render/composition_entry.dart';

import 'harness_audio.dart';
import 'harness_snapshot.dart';

/// Builds a [MediaResolver] for [entry] and pre-resolves every declared source
/// before frame 0, or returns `null` when [entry] declares no media.
///
/// This is the default the capture harness uses: a real [MediaRepository] over
/// the example's `rootBundle`, with the ffmpeg-backed probe and frame extractor
/// the clip path needs. Image sources are resolved (fetched, hashed, decoded)
/// in one pass; each clip is probed and every one of its source frames is
/// pre-extracted, so the resampler always finds the frame it asks for. The
/// `ffmpeg`/`ffprobe` binaries must be on `PATH` whenever a composition declares
/// a clip; an untagged test that wants to avoid them passes its own resolver.
typedef PrepareMedia = Future<MediaResolver?> Function(CompositionEntry entry);

/// The default [PrepareMedia]: a real repository over the asset bundle.
///
/// One [MediaRepository] resolves every kind a composition declares: its
/// `Image`/`Clip` sources through the ffmpeg-backed path, and — for a lesson
/// that declares snapshots (lesson 09's `Mermaid`/`WebView`/`Html`) — its
/// `SnapshotSource`s through the bundled offline fake backend. The example is a
/// consumer that injects its own offline snapshot service, so lesson 09 renders
/// deterministically with no Chromium and no network. Returns `null` only when
/// the composition declares neither media nor snapshots.
Future<MediaResolver?> prepareEntryMedia(CompositionEntry entry) async {
  final sources = entry.mediaSources;
  final snapshots = _snapshotSourcesFor(entry);
  final captions = _captionSourceFor(entry);
  final reactiveVideo = _reactiveVideoFor(entry);
  if (sources.isEmpty && snapshots.isEmpty && captions == null && reactiveVideo == null) {
    return null;
  }
  // The untrusted Playground render sets this define so a submitted snippet,
  // spec, or AI-authored spec cannot read the host's filesystem through a
  // FileSource. Only a trusted key/lesson render (a bundled, developer-authored
  // composition) leaves it off and reads local files normally.
  final repository = MediaRepository(
    loader: MediaBytesLoader(
      bundle: rootBundle,
      httpClient: const _OfflineHttpClient(),
      allowlist: NetworkAllowlist.allowAny(),
      // A build-time define, true only on the untrusted Playground path (it
      // reads false here, at analysis time, which is not the same as unset).
      // ignore: avoid_redundant_argument_values
      blockFileSources: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
    ),
    probeService: const FfprobeVideoProbeService(),
    frameExtractor: const FfmpegFrameExtractionService(),
  );

  final images = sources.where(_isImage).toList();
  final clips = sources.where((source) => !_isImage(source)).toList();
  await repository.preResolveAll(images);
  for (final clip in clips) {
    await _preResolveWholeClip(repository, clip);
  }
  await preResolveSnapshotsOnto(repository, snapshots);
  if (captions != null) await repository.preResolveCaptions(captions);
  if (reactiveVideo != null) {
    // Decode the committed WAV with the in-house reader and run the real
    // spectral beat/band DSP before frame 0 — no ffmpeg in the gate path.
    await preResolveReactiveFor(
      repository,
      reactiveVideo,
      fps: entry.fps,
      totalFrames: entry.frameCount,
    );
  }
  return repository;
}

/// The lesson [video] [entry] keys when it declares reactive audio (the music
/// bed lesson 10 analyses), or `null` when it has no audio to analyse.
///
/// The reactive pre-pass needs the whole `Video` (not just the media sources) so
/// it can read the `Audio` tracks the collect pass gathers. A non-lesson entry
/// (`demo`/`multi_scene`) declares no audio, so it yields `null`.
Video? _reactiveVideoFor(CompositionEntry entry) {
  final lesson = lessonForId(entry.key);
  if (lesson == null) return null;
  final video = lesson.video();
  return collectAudioSources(video).isEmpty ? null : video;
}

/// Returns the encoder audio-mix staging a render needs (decision D-Audio /
/// D-Mix) — the default is [prepareEntryAudioStaging]; a test injects its own to
/// drive an audio composition through the full harness without a lesson key.
typedef PrepareAudioStaging =
    ({AudioMixStager? stageAudio, List<AudioSource> audioSources}) Function(
      CompositionEntry entry,
      MediaResolver? resolver,
    );

/// The default [PrepareAudioStaging]: reads the lesson [entry] keys, collects its
/// declared `Audio` tracks, and (when it has any) builds the staging closure via
/// [audioStagingFor] + the `audioSources` the resolver materializes before the
/// frame loop (decision D-Audio). A non-lesson or silent entry yields
/// `(null, [])`, so the encoder's `-an` path is unchanged — the demo and
/// `multi_scene` stay silent.
///
/// This is the production wiring the AUDMIX-WIRE fix closes: lesson 12's
/// `Audio.music` is now staged into the manifest's `-filter_complex`/`[aout]`
/// mix instead of being dropped to `-an`.
({AudioMixStager? stageAudio, List<AudioSource> audioSources}) prepareEntryAudioStaging(
  CompositionEntry entry,
  MediaResolver? resolver,
) {
  final video = lessonForId(entry.key)?.video();
  if (video == null) return (stageAudio: null, audioSources: const []);
  return audioStagingFor(
    video,
    resolver: resolver,
    fps: entry.fps,
    totalFrames: entry.frameCount,
  );
}

/// The snapshot sources [entry] declares, gathered from the lesson it keys (the
/// package collect-pass descends through `DeviceFrame`/`Frame`/`Snapshot`). A
/// non-lesson entry (`demo`/`multi_scene`) declares no snapshots, so the set is
/// empty.
Set<SnapshotSource> _snapshotSourcesFor(CompositionEntry entry) {
  final lesson = lessonForId(entry.key);
  if (lesson == null) return const <SnapshotSource>{};
  return collectSnapshotSources(lesson.video().scenes);
}

/// The caption source [entry] declares, read from the lesson it keys, or `null`
/// when the lesson has no caption track (decision D-CaptionsRender). The caption
/// pre-pass reads + parses the SRT/VTT file before frame 0, exactly like media.
CaptionSource? _captionSourceFor(CompositionEntry entry) {
  final lesson = lessonForId(entry.key);
  if (lesson == null) return null;
  return collectCaptionSource(lesson.video());
}

/// Returns the scenes a render needs for its [Snapshot] capture pre-pass — the
/// default is [entryScenes]; a test injects its own to drive a Snapshot
/// composition through the full harness.
typedef SnapshotScenes = List<Scene> Function(CompositionEntry entry);

/// The scenes [entry] composes, read from the lesson it keys, or empty for a
/// non-lesson entry (`demo`/`multi_scene`).
///
/// The render shell uses this to gather the entry's `Snapshot` widgets for the
/// in-process capture pre-pass: `lesson.video()` builds a fresh tree on every
/// call, so the n-th `Snapshot` here is the n-th `Snapshot` the frame loop builds
/// (the trees are structurally identical and deterministic). A non-lesson entry
/// has no scenes the shell can walk for snapshots, so it yields none.
List<Scene> entryScenes(CompositionEntry entry) =>
    lessonForId(entry.key)?.video().scenes ?? const <Scene>[];

/// Returns the reactive audio tracks a render needs to mount its `ReactiveScope`
/// — the default is [reactiveTracksFor]; a test injects its own to drive a
/// reactive composition through the full harness.
typedef ReactiveTracksFor = ReactiveTracks Function(CompositionEntry entry);

/// The reactive audio tracks [entry] declares, read from the lesson it keys
/// (decision D-Reactive). A non-lesson entry, or a lesson with no `Audio`,
/// yields empty tracks, so the shell mounts no `ReactiveScope`.
///
/// `lesson.video()` is deterministic, so the tracks gathered here name the same
/// `AudioSource`s the pre-pass analysed — the resolver answers `bandTableFor`
/// for each, and the mounted scope serves those tables to the reactive effects
/// in the frame loop.
ReactiveTracks reactiveTracksFor(CompositionEntry entry) {
  final lesson = lessonForId(entry.key);
  if (lesson == null) {
    return const ReactiveTracks(byAnchor: {}, defaultSource: null, allSources: {});
  }
  return collectReactiveTracks(lesson.video());
}

/// Probes [clip] and pre-extracts every source frame, so any composition frame
/// the resampler maps into the clip finds a decoded frame waiting.
Future<void> _preResolveWholeClip(MediaRepository repository, MediaSource clip) async {
  final path = await _materialize(clip);
  try {
    final probe = await const FfprobeVideoProbeService().probe(path);
    final frames = List<int>.generate(probe.nbFrames, (index) => index);
    await repository.preResolveClip(clip, frames);
  } finally {
    // The materialized file existed only for the probe; the repository
    // re-resolves the clip itself. Delete the temp dir so a multi-clip render
    // does not pile up in /tmp (which can fill the tmpfs and hang the gate).
    final dir = File(path).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// Writes [clip]'s bytes to a temp file the probe can read, returning its path.
Future<String> _materialize(MediaSource clip) async {
  final loader = MediaBytesLoader(
    bundle: rootBundle,
    httpClient: const _OfflineHttpClient(),
    allowlist: NetworkAllowlist.allowAny(),
    // The clip pre-pass reads on the same untrusted path as the main loader, so
    // it honors the same FileSource block; without it Clip.file('/host.mp4')
    // would read a host file into worker memory even on the hardened path.
    // ignore: avoid_redundant_argument_values
    blockFileSources: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
  );
  final bytes = await loader.load(clip);
  final dir = await Directory.systemTemp.createTemp('fluvie_harness_clip_');
  final file = File('${dir.path}/clip.mp4');
  await file.writeAsBytes(bytes);
  return file.path;
}

/// Whether [source]'s extension reads as an image (anything that is not a clip
/// is treated as an image by the resolver's decode pass).
bool _isImage(MediaSource source) => switch (source) {
  AssetSource(:final name) => !_isVideoName(name),
  FileSource(:final path) => !_isVideoName(path),
  NetworkSource(:final url) => !_isVideoName(url.path),
  MemorySource() => true,
};

bool _isVideoName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm');
}

/// The harness never reaches the live network: every fixture is a bundled
/// asset, so an unexpected network source is a determinism bug, not a fetch.
class _OfflineHttpClient implements MediaHttpClient {
  const _OfflineHttpClient();

  @override
  Future<Uint8List> get(Uri url) async => throw StateError(
    'The capture harness resolves only bundled fixtures; an unexpected network '
    'source ($url) would break offline determinism.',
  );
}
