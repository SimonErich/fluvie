/// A frequency band of an analysed audio track, driving spectrum-reactive
/// animations.
///
/// ```dart
/// Bars(count: 24).animate([Animation.scaleY(on: AudioBand.bass, gain: 1.5)])
/// ```
enum AudioBand {
  /// Low frequencies — kick drums, bass lines.
  bass,

  /// Mid frequencies — vocals, most melodic instruments.
  mid,

  /// High frequencies — hi-hats, cymbals, sibilance.
  treble,
}
