/// A platform audio face for the same clock that drives video preview.
///
/// Backends may play a prepared mix or synchronize individual lanes. The host
/// retains ownership. Browser implementations unlock audio in [activate],
/// called by a user gesture, and correct drift rather than seek on every tick.
abstract interface class PreviewAudioController {
  /// Unlocks platform audio from a user gesture.
  Future<void> activate();

  /// Synchronizes playback with the canonical composition clock.
  Future<void> synchronize({
    required Duration position,
    required bool playing,
    required double rate,
  });

  /// Releases backend resources; called by the owning application.
  Future<void> dispose();
}
