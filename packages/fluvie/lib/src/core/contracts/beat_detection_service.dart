import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/contracts/beat_grid.dart';

/// Detects the beats of one audio track and emits them as a [BeatGrid] in
/// absolute video-frame space.
///
/// This is the contract `Trigger.beat` resolves against: the real implementation
/// decodes the track to PCM once before frame 0, runs the in-house spectral-flux
/// onset detector, snaps the onsets to absolute video frames at the render fps,
/// and content-hash caches the grid as JSON. Detection is async (it may spawn
/// ffmpeg to decode), so it runs entirely in the pre-resolve pass — the frame
/// loop only ever queries the resulting immutable grid.
///
/// The gate default reads a committed WAV through an in-house decoder (no
/// ffmpeg); the live ffmpeg-decode path is exercised behind the `ffmpeg` test
/// tag. The analyse-twice→identical-grid property is the determinism proof.
///
/// `BeatGrid` is the queryable result; the real `SpectralBeatDetectionService`
/// is named in prose because it lives in a layer above `core`.
// One member by design: the contract is the *type*, injected via a provider so
// the timing engine resolves `Trigger.beat` against a real grid at render and a
// fake in tests.
// ignore: one_member_abstracts
abstract interface class BeatDetectionService {
  /// Detects [source]'s beats and returns them as a [BeatGrid] over a video of
  /// [totalFrames] frames at [fps].
  ///
  /// Runs in the pre-resolve pass before the frame loop. Throws a
  /// `FluvieRenderException` when the source cannot be decoded.
  Future<BeatGrid> detect(AudioSource source, {required int fps, required int totalFrames});
}
