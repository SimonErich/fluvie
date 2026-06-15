import 'package:fluvie/src/audio/runtime/ffmpeg_pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/frame_list_beat_grid.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/onset_detector.dart';
import 'package:fluvie/src/core/audio/dsp/spectral_flux.dart';
import 'package:fluvie/src/core/contracts/beat_detection_service.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';

/// The real [BeatDetectionService]: decode → in-house spectral-flux onset
/// detection → onsets snapped to absolute video frames → an immutable
/// [FrameListBeatGrid], content-hash cached so a re-detect over the same source
/// is a free lookup.
///
/// Wired as the provider default, it gives the `Trigger.beat` resolver a real
/// grid where the test `FakeBeatGrid` stands in. The impure decode is the
/// injected [PcmDecoder] (the default reads a committed WAV; the live path
/// spawns ffmpeg), so everything from the PCM onward is pure and the
/// analyse-twice→identical-grid property holds.
final class SpectralBeatDetectionService implements BeatDetectionService {
  /// Creates a service decoding through [decoder] (defaults to the ffmpeg-backed
  /// [FfmpegPcmDecoder]).
  SpectralBeatDetectionService({PcmDecoder decoder = const FfmpegPcmDecoder()})
    : _decoder = decoder; // ignore: prefer_initializing_formals — public arg `decoder`

  final PcmDecoder _decoder;

  // Detected grids keyed by source cacheKey + fps + totalFrames, so a repeated
  // detect over the same declaration skips the decode + DSP entirely.
  final Map<String, BeatGrid> _cache = {};

  @override
  Future<BeatGrid> detect(
    AudioSource source, {
    required int fps,
    required int totalFrames,
  }) async {
    final key = '${source.cacheKey}|$fps|$totalFrames';
    final cached = _cache[key];
    if (cached != null) return cached;
    final pcm = await _decoder.decode(source);
    final flux = spectralFlux(pcm.samples);
    final onsetHops = detectOnsets(flux);
    final frames = onsetFramesAt(
      onsetHops,
      hopSize: SpectralFlux.defaultHopSize,
      sampleRate: pcm.sampleRate,
      fps: fps,
    ).where((frame) => frame < totalFrames).toList();
    final grid = FrameListBeatGrid(frames);
    _cache[key] = grid;
    return grid;
  }
}
