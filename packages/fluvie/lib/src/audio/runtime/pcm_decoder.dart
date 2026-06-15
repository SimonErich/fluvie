import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/audio/dsp/wav_reader.dart';

/// Decodes one [AudioSource] to mono [PcmAudio] for the in-house DSP — the
/// interface the beat detector and frequency analyzer share.
///
/// It isolates the one impure step (reading bytes, possibly spawning ffmpeg)
/// behind an injectable boundary, so the default analysis tests feed a
/// committed WAV through a pure in-house decoder while the live path spawns
/// ffmpeg. Decoding runs only in the pre-resolve pass before frame 0; the DSP
/// that consumes the result is pure and deterministic.
///
/// The real ffmpeg-backed decoder is named in prose; the tests inject a
/// WAV-reader decoder.
// One member by design: the contract is the *type*, injected so analysis runs
// without ffmpeg.
// ignore: one_member_abstracts
abstract interface class PcmDecoder {
  /// Decodes [source] to mono [PcmAudio] (samples in `[-1, 1]` at the source
  /// sample rate).
  Future<PcmAudio> decode(AudioSource source);
}
