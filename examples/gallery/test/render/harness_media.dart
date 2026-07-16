import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
// The media wiring the harness injects is the real, ffmpeg-backed pipeline; it
// lives under `src/` because a repository is render infrastructure, not part of
// the authoring surface a lesson imports. The caption and reactive collectors
// are the same: `renderVideo` reads them to decide whether a render declares
// media, and this mirrors that decision to pick the resolver.
import 'package:fluvie/src/composition/runtime/caption_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';

/// Builds the [MediaResolver] a render of [video] needs, or `null` when it
/// declares no media at all (so the render never touches ffmpeg or the bundle).
///
/// `renderVideo` pre-resolves through whatever resolver it is handed; this only
/// chooses which one. An untagged test that wants to avoid ffmpeg entirely passes
/// its own.
typedef PrepareMedia = Future<MediaResolver?> Function(Video video);

/// The default [PrepareMedia]: a real [MediaRepository] over the example's asset
/// bundle, with the ffmpeg-backed probe and frame extractor the clip path needs.
///
/// The `ffmpeg`/`ffprobe` binaries must be on `PATH` whenever a composition
/// declares a clip. Returns `null` for a composition that declares no media,
/// snapshots, captions, or reactive audio, which is what keeps the media-less
/// acceptance renders (`demo`, `multi_scene`) free of any toolchain.
Future<MediaResolver?> prepareEntryMedia(Video video) async {
  final declaresMedia =
      collectMediaSources(video.scenes).isNotEmpty ||
      collectSnapshotSources(video.scenes).isNotEmpty ||
      collectCaptionSource(video) != null ||
      collectReactiveTracks(video).allSources.isNotEmpty;
  if (!declaresMedia) return null;
  return MediaRepository(
    loader: MediaBytesLoader(
      bundle: rootBundle,
      httpClient: const _OfflineHttpClient(),
      allowlist: NetworkAllowlist.allowAny(),
      // The untrusted Playground render sets this define so a submitted snippet
      // cannot read the host's filesystem through a FileSource. A trusted lesson
      // render leaves it off and reads local files normally. It reads false here,
      // at analysis time, which is not the same as unset.
      // ignore: avoid_redundant_argument_values
      blockFileSources: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
    ),
    probeService: const FfprobeVideoProbeService(),
    frameExtractor: const FfmpegFrameExtractionService(),
  );
}

/// The harness never reaches the live network: every fixture is a bundled asset,
/// so an unexpected network source is a determinism bug, not a fetch.
class _OfflineHttpClient implements MediaHttpClient {
  const _OfflineHttpClient();

  @override
  Future<Uint8List> get(Uri url) async => throw StateError(
    'The capture harness resolves only bundled fixtures; an unexpected network '
    'source ($url) would break offline determinism.',
  );
}
