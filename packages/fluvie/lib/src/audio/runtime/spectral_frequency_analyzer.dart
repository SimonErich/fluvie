import 'dart:typed_data';

import 'package:fluvie/src/audio/runtime/ffmpeg_pcm_decoder.dart';
import 'package:fluvie/src/audio/runtime/pcm_decoder.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/band_table.dart';
import 'package:fluvie/src/core/audio/dsp/fft.dart';
import 'package:fluvie/src/core/audio/dsp/spectral_flux.dart';
import 'package:fluvie/src/core/audio_band.dart';
import 'package:fluvie/src/core/contracts/frequency_analyzer.dart';

/// The real [FrequencyAnalyzer]: decode → per-hop FFT band sums → resampled,
/// peak-normalized per-frame [BandTable], content-hash cached so a re-analyze
/// over the same source is a free lookup.
///
/// It reuses the same 1024/512 Hann frames the spectral-flux pass uses, summing
/// each frame's magnitude spectrum into the bass / mid / treble bins, then
/// resampling those per-hop sums onto one value per video frame. The impure
/// decode is the injected [PcmDecoder] (the default reads a committed WAV; the
/// live path spawns ffmpeg), so everything from the PCM onward is pure and the
/// analyse-twice→identical-table property holds.
final class SpectralFrequencyAnalyzer implements FrequencyAnalyzer {
  /// Creates an analyzer decoding through [decoder] (defaults to the
  /// ffmpeg-backed [FfmpegPcmDecoder]).
  SpectralFrequencyAnalyzer({PcmDecoder decoder = const FfmpegPcmDecoder()})
    : _decoder = decoder; // ignore: prefer_initializing_formals — public arg `decoder`

  final PcmDecoder _decoder;

  // Tables keyed by source cacheKey + fps + totalFrames, so a repeated analyze
  // over the same declaration skips the decode + DSP entirely.
  final Map<String, BandTable> _cache = {};

  @override
  Future<BandTable> analyze(
    AudioSource source, {
    required int fps,
    required int totalFrames,
  }) async {
    final key = '${source.cacheKey}|$fps|$totalFrames';
    final cached = _cache[key];
    if (cached != null) return cached;
    final pcm = await _decoder.decode(source);
    final hops = _bandHops(pcm.samples, pcm.sampleRate);
    final table = BandTable.fromHops(
      hops,
      hopSize: SpectralFlux.defaultHopSize,
      sampleRate: pcm.sampleRate,
      fps: fps,
      totalFrames: totalFrames,
    );
    _cache[key] = table;
    return table;
  }

  /// Sums each 1024/512 Hann frame's magnitude spectrum into the three band
  /// ranges, returning one per-hop list per band.
  Map<AudioBand, Float64List> _bandHops(Float64List samples, int sampleRate) {
    const windowSize = SpectralFlux.defaultWindowSize;
    const hopSize = SpectralFlux.defaultHopSize;
    if (samples.length < windowSize) {
      return {for (final band in AudioBand.values) band: Float64List(0)};
    }
    final frameCount = (samples.length - windowSize) ~/ hopSize + 1;
    final bass = Float64List(frameCount);
    final mid = Float64List(frameCount);
    final treble = Float64List(frameCount);
    final frame = Float64List(windowSize);
    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;
      for (var i = 0; i < windowSize; i++) {
        frame[i] = samples[start + i];
      }
      final magnitudes = fftMagnitudes(applyHann(frame));
      final energies = bandEnergies(magnitudes, sampleRate: sampleRate, windowSize: windowSize);
      bass[f] = energies.bass;
      mid[f] = energies.mid;
      treble[f] = energies.treble;
    }
    return {AudioBand.bass: bass, AudioBand.mid: mid, AudioBand.treble: treble};
  }
}
