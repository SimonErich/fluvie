import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie/rendering.dart';
// The reactive pre-pass is render infrastructure under `src/`: the audio
// collectors, the WAV reader, and the PcmDecoder seam are off the authoring
// surface a lesson imports, exactly like the snapshot and caption harness wiring.
import 'package:fluvie/src/audio/encoding/audio_mix_staging.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/spectral_beat_detection_service.dart';
import 'package:fluvie/src/audio/runtime/spectral_frequency_analyzer.dart';
import 'package:fluvie/src/composition/runtime/audio_collector.dart';
import 'package:fluvie/src/composition/runtime/reactive_collector.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';
import 'package:fluvie/src/media/media_bytes_loader.dart';
import 'package:fluvie/src/media/media_repository.dart';
import 'package:fluvie/src/media/net/media_http_client.dart';
import 'package:fluvie/src/rendering/encoding/ffmpeg_frame_extraction_service.dart';
import 'package:fluvie/src/rendering/encoding/video_probe_service.dart';

/// A [PcmDecoder] that reads a committed WAV file straight off disk with the
/// in-house [readPcmWav] reader — no ffmpeg, so the reactive analysis runs in
/// the gate.
///
/// The `MediaRepository` materializes each declared `AudioSource` to a temp file
/// and hands the services a [FileAudioSource] pointing at it, so this decoder
/// only ever sees a file path. It rejects anything that is not a file source,
/// because the example commits WAV fixtures precisely so the gate path never
/// reaches ffmpeg (decision D-Lesson / D-DSP).
final class WavFilePcmDecoder implements PcmDecoder {
  /// Creates the offline WAV decoder.
  const WavFilePcmDecoder();

  @override
  Future<PcmAudio> decode(AudioSource source) async {
    final path = switch (source) {
      FileAudioSource(:final path) => path,
      _ => throw StateError(
        'The example reactive pre-pass decodes only committed WAV files; the '
        'repository materializes every AudioSource to a file before analysis, '
        'so an unexpected source ($source) would mean a non-WAV fixture or a '
        'live ffmpeg decode breaking offline determinism.',
      ),
    };
    return readPcmWav(await File(path).readAsBytes());
  }
}

/// Runs the offline reactive pre-pass for [video] onto [resolver]: collects the
/// declared `Audio` tracks and analyses each one into a beat grid and a band
/// table with the real spectral services over the in-house WAV decoder.
///
/// This is the gate-default the capture harness uses for an audio lesson: the
/// real `SpectralBeatDetectionService` / `SpectralFrequencyAnalyzer` run over
/// the committed WAV (via [WavFilePcmDecoder]), so the band table the
/// `ReactiveScope` serves and the beat grid `Trigger.beat` reads are computed
/// once before frame 0 with no ffmpeg. A composition that declares no audio is a
/// no-op. The analysis is pure and deterministic, so two runs over the same WAV
/// produce identical tables (the determinism proof the lesson leans on).
Future<void> preResolveReactiveFor(
  MediaResolver resolver,
  Video video, {
  required int fps,
  required int totalFrames,
}) async {
  final tracks = collectReactiveTracks(video);
  if (tracks.allSources.isEmpty) return;
  await resolver.preResolveReactive(
    tracks.allSources,
    beatDetector: SpectralBeatDetectionService(decoder: const WavFilePcmDecoder()),
    analyzer: SpectralFrequencyAnalyzer(decoder: const WavFilePcmDecoder()),
    fps: fps,
    totalFrames: totalFrames,
  );
}

/// What the harness needs to stage [video]'s audio mix into the encode plan: the
/// `audioSources` the resolver must materialize before the frame loop, and the
/// `stageAudio` closure `RenderService.captureToDirectory` invokes to build the
/// encoder lanes (decision D-Audio / D-Mix), or `(null, [])` for a silent
/// composition.
///
/// This is the production wiring the AUDMIX-WIRE fix closes: without it the
/// capture path saw `stageAudio == null`, emitted `-an`, and rendered a silent
/// video. The closure invokes the production [stageAudioMix] over [video]'s
/// collected `Audio` tracks against [fps]/[totalFrames] (so `Audio.sfx(at:)`
/// resolves its `adelay`). The actual encode of the staged audio is ffmpeg work;
/// building the manifest's args here is offline and gate-runnable.
({AudioMixStager? stageAudio, List<AudioSource> audioSources}) audioStagingFor(
  Video video, {
  required MediaResolver? resolver,
  required int fps,
  required int totalFrames,
}) {
  final tracks = collectAudioTracks(video);
  if (tracks.isEmpty || resolver == null) {
    return (stageAudio: null, audioSources: const []);
  }
  return (
    stageAudio: ({required resolver, required sandbox}) async {
      final plan = await stageAudioMix(
        tracks: tracks,
        resolver: resolver,
        sandbox: sandbox,
        fps: fps,
        totalFrames: totalFrames,
      );
      return (nodes: plan.tracks, amix: plan.amix);
    },
    audioSources: collectAudioSources(video).toList(),
  );
}

/// A real, offline [MediaRepository] over the example asset bundle for audio
/// materialization: it copies a committed WAV's bytes into the render sandbox so
/// `materializedAudioPathFor` answers during staging — no ffmpeg, no network.
///
/// `MediaRepository.preResolveAudio` is a plain bundle read plus a byte copy, so
/// the manifest-build path the gate runs needs no decoder. The probe and frame
/// extractor are wired only because the repository requires them; the audio path
/// never reaches either.
MediaRepository offlineAudioRepository() => MediaRepository(
  loader: MediaBytesLoader(
    bundle: rootBundle,
    httpClient: const _OfflineAudioHttpClient(),
    allowlist: NetworkAllowlist.allowAny(),
    // Defense-in-depth: untrusted audio is dropped upstream today, but honor the
    // untrusted define so this loader stays hardened if ever wired in.
    // ignore: avoid_redundant_argument_values
    blockFileSources: const bool.fromEnvironment('FLUVIE_BLOCK_FILE_SOURCES'),
  ),
  probeService: const FfprobeVideoProbeService(),
  frameExtractor: const FfmpegFrameExtractionService(),
);

/// The harness resolves only bundled WAV fixtures; a live audio fetch would
/// break offline determinism, so it is a bug, not a download.
class _OfflineAudioHttpClient implements MediaHttpClient {
  const _OfflineAudioHttpClient();

  @override
  Future<Uint8List> get(Uri url) async => throw StateError(
    'The capture harness materializes only bundled audio fixtures; an unexpected '
    'network source ($url) would break offline determinism.',
  );
}
