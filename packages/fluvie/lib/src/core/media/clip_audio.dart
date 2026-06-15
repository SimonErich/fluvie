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
/// clip's track (with a [volume] and an optional [fadeIn]) and
/// [ClipAudio.muted] drops it. Values are equal by their fields so two clips
/// with the same policy compare equal.
///
/// `Clip` is named in prose, not as a doc link, because it lives in a layer
/// above `core` and a link would invert the layering.
@immutable
final class ClipAudio {
  /// Keeps the clip's audio at [volume] (`0`..`1`, default full), optionally
  /// ramping up over [fadeIn] from the clip's start.
  ///
  /// The mixing pipeline consumes [volume] and [fadeIn] when it mixes the
  /// clip's track into the video at render; the element records them as data.
  const ClipAudio.included({this.volume = 1.0, this.fadeIn = Time.zero})
    : muted = false,
      assert(volume >= 0.0 && volume <= 1.0, 'volume must be within 0..1');

  /// Drops the clip's audio entirely: [muted] is `true`, [volume] is `0`, and
  /// there is no [fadeIn].
  // coverage:ignore-line: const-ctor artifact, behavior pinned by clip_audio tests
  const ClipAudio.muted() : muted = true, volume = 0.0, fadeIn = Time.zero;

  /// Whether the clip's audio is dropped (`true` for [ClipAudio.muted]).
  final bool muted;

  /// The playback volume in `0`..`1`; `0` when [muted].
  final double volume;

  /// How long the clip's audio ramps up from silence at its start;
  /// [Time.zero] for no fade.
  final Time fadeIn;

  @override
  bool operator ==(Object other) =>
      other is ClipAudio &&
      other.muted == muted &&
      other.volume == volume &&
      other.fadeIn == fadeIn;

  @override
  int get hashCode => Object.hash(ClipAudio, muted, volume, fadeIn);

  @override
  String toString() =>
      muted ? 'ClipAudio.muted()' : 'ClipAudio.included(volume: $volume, fadeIn: $fadeIn)';
}
