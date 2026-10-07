import 'package:fluvie/src/core/audio/audio_automation.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:meta/meta.dart';

/// The audio policy a `Clip` carries — a data-only value type.
///
/// A clip declares *whether* and *how* its embedded audio plays; the audio
/// mixing pipeline consumes this policy at render. A
/// `ClipAudio` is inert metadata the element holds: it never touches a player,
/// so it lives in `core` (only [Time] and Dart-core types, no IO).
///
/// Two factories cover the two honest choices: [ClipAudio.included] keeps the
/// clip's track (with a [volume] and optional [fadeIn]/[fadeOut] ramps) and
/// [ClipAudio.muted] drops it. Values are equal by their fields so two clips
/// with the same policy compare equal.
///
/// `Clip` is named in prose, not as a doc link, because it lives in a layer
/// above `core` and a link would invert the layering.
@immutable
final class ClipAudio {
  /// Keeps the clip's audio at [volume] (nonnegative, default full), optionally
  /// ramping up over [fadeIn] from the clip's start and down over [fadeOut]
  /// into its end.
  ///
  /// Both ramps are anchored to the clip's own window, not to the source file:
  /// the fade-in starts where the clip starts and the fade-out ends where the
  /// clip stops being shown. The mixing pipeline consumes them at render; the
  /// element records them as data.
  const ClipAudio.included({
    this.volume = 1.0,
    this.automation = const AudioAutomation(),
    this.fadeIn = Time.zero,
    this.fadeOut = Time.zero,
  }) : muted = false,
       assert(volume >= 0.0 && volume < double.infinity, 'volume must be finite and nonnegative');

  /// Drops the clip's audio entirely: [muted] is `true`, [volume] is `0`, and
  /// there are no ramps.
  // coverage:ignore-line const ctor artifact behavior pinned by clip_audio tests
  const ClipAudio.muted()
    : muted = true,
      volume = 0.0,
      fadeIn = Time.zero,
      fadeOut = Time.zero,
      automation = const AudioAutomation();

  /// Whether the clip's audio is dropped (`true` for [ClipAudio.muted]).
  final bool muted;

  /// The nonnegative playback gain; values above one amplify. `0` when [muted].
  final double volume;

  /// Volume automation relative to the clip window.
  final AudioAutomation automation;

  /// How long the clip's audio ramps up from silence at its start;
  /// [Time.zero] for no fade.
  final Time fadeIn;

  /// How long the clip's audio ramps down to silence into its end;
  /// [Time.zero] for no fade.
  ///
  /// The ramp *ends* where the clip stops being shown, so it begins that much
  /// earlier — a half-second fade on a clip that ends at five seconds starts at
  /// four and a half.
  final Time fadeOut;

  /// Multiplies gain while preserving authored automation, fades and mute.
  ClipAudio scaledBy(double gain) {
    if (!gain.isFinite || gain < 0 || !(volume * gain).isFinite) {
      throw ArgumentError.value(gain, 'gain', 'must produce a finite nonnegative volume');
    }
    if (muted) return this;
    return ClipAudio.included(
      volume: volume * gain,
      automation: automation,
      fadeIn: fadeIn,
      fadeOut: fadeOut,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClipAudio &&
      other.muted == muted &&
      other.volume == volume &&
      other.fadeIn == fadeIn &&
      other.fadeOut == fadeOut &&
      other.automation == automation;

  @override
  int get hashCode => Object.hash(ClipAudio, muted, volume, fadeIn, fadeOut, automation);

  @override
  String toString() => muted
      ? 'ClipAudio.muted()'
      : 'ClipAudio.included(volume: $volume, fadeIn: $fadeIn, fadeOut: $fadeOut)';
}
