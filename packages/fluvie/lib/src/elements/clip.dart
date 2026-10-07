import 'dart:typed_data';

import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
import 'package:fluvie/src/animation/keyframed_number.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/media_carrier.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/media/snapshot_source.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_painter.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';

/// An embedded video — Fluvie's own widget under Flutter's familiar `Clip` name
/// (the barrel hides Flutter's).
///
/// Fluvie probes the source during composition preparation, then resolves the
/// required source frames before each capture or preview paint. Export hosts
/// use bounded decode-ahead rather than holding the whole video in memory.
/// Painting reads the prepared image synchronously. The composition frame is
/// mapped to a source frame by the
/// floor-resampling rule, so a slow source under a fast composition holds frames
/// instead of skipping. A capture with no pre-resolution throws a
/// `FluvieRenderException` naming the source. `VideoPreview` prepares and plays
/// real clip frames; a bare widget without a prepared resolver shows its poster
/// or a labelled placeholder. `PreviewMediaScope` supplies the preparation
/// lifecycle for custom preview hosts.
///
/// ```dart
/// Clip.asset('intro.mp4', trim: 2.seconds.to(7.seconds),
///   audio: ClipAudio.included(volume: 0.6, fadeIn: 0.3.seconds))
///     .animate([Animation.fadeIn(), Animation.fadeOut()]);
/// Clip.network(Uri.parse('https://…/b-roll.mp4'));
/// ```
///
/// [source] exposes the declared [MediaSource] for the collect pass
/// (`collectMediaSources`). [trim] selects a portion of the source in source
/// time; [audio] declares the clip's audio policy (data-only; the audio pipeline
/// consumes it at render); [shared] wraps the result in a `SharedElement` for a
/// hero morph across a scene boundary. Transforms and effects come through
/// `.animate()` only, like every element.
///
/// The name deliberately shadows the `dart:ui` `Clip` enum (the standard
/// prelude hides it), so a bare `clipBehavior: Clip.antiAlias` does not
/// resolve inside a video file. Reach the enum through a prefix when you need
/// it: `import 'package:flutter/widgets.dart' as flutter;` then
/// `flutter.Clip.antiAlias`.
final class Clip extends StatelessWidget implements MediaCarrier {
  /// A bundled video addressed by its asset key [name]
  /// (for example `fixtures/clip_1s.mp4`).
  Clip.asset(
    String name, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    this.poster,
    this.speed = 1,
    this.speedRamp,
    super.key,
  }) : assert(_isRate(speed), _rateMessage),
       assert(speedRamp == null || speed == 1, 'Use speedRamp with the default scalar speed of 1.'),
       source = MediaSource.asset(name);

  /// A remote video at [url]; only allowlisted hosts and schemes are fetched in
  /// capture.
  Clip.network(
    Uri url, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    this.poster,
    this.speed = 1,
    this.speedRamp,
    super.key,
  }) : assert(_isRate(speed), _rateMessage),
       assert(speedRamp == null || speed == 1, 'Use speedRamp with the default scalar speed of 1.'),
       source = MediaSource.network(url);

  /// A video file on disk at [path]. Composition preparation identifies this
  /// widget as a clip explicitly; the configured decoder determines which
  /// containers it supports. For a scoped-storage source the caller copies it
  /// to a readable app-private path first.
  Clip.file(
    String path, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    this.poster,
    this.speed = 1,
    this.speedRamp,
    super.key,
  }) : assert(_isRate(speed), _rateMessage),
       assert(speedRamp == null || speed == 1, 'Use speedRamp with the default scalar speed of 1.'),
       source = MediaSource.file(path);

  /// A video already in memory as raw encoded [bytes] (an imported file that
  /// never touched disk). [debugLabel] gives it a useful name in diagnostics;
  /// composition preparation identifies it as a clip even without a label.
  /// Its embedded audio joins the
  /// encoder mix like any other clip's: the bytes materialize to a temp file
  /// the encoder reads, and the [audio] policy applies unchanged.
  Clip.memory(
    Uint8List bytes, {
    String? debugLabel,
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    this.poster,
    this.speed = 1,
    this.speedRamp,
    super.key,
  }) : assert(_isRate(speed), _rateMessage),
       assert(speedRamp == null || speed == 1, 'Use speedRamp with the default scalar speed of 1.'),
       source = MediaSource.memory(bytes, debugLabel: debugLabel);

  /// The declared media this clip plays — the key the collect pass gathers and
  /// the resolver pre-resolves.
  final MediaSource source;

  /// This clip's [source], exposed through the [MediaCarrier] contract so the
  /// collect pass reads it without importing the elements layer.
  @override
  MediaSource? get mediaSource => source;

  /// A `Clip` declares no snapshot — it is a loaded media, not a computed one.
  @override
  SnapshotSource? get snapshotSource => null;

  /// The portion of the source video to play, in source time, or `null` for
  /// the whole clip.
  final TimeRange? trim;

  /// The clip's audio policy. Data-only; the audio pipeline consumes it at
  /// render.
  final ClipAudio audio;

  /// An optional hero anchor: when non-null the clip morphs across the boundary
  /// it shares with the same anchor in the adjacent scene. `null` mounts no
  /// `SharedElement`.
  final Anchor? shared;

  /// How the frame scales into its box, or `null` for Flutter's default.
  final BoxFit? fit;

  /// A still shown when no prepared clip resolver is available, or `null` for
  /// the labelled placeholder. A capture
  /// always paints real frames, so the poster never reaches a render.
  final MediaSource? poster;

  /// The playback rate: `1` plays at source speed, `0.5` at half, `2` at
  /// double. A negative rate plays the [trim] backwards from its last frame.
  ///
  /// The rate retimes the picture and the embedded audio together.
  ///
  /// A reversed clip plays **no** audio: no filter in this graph reverses a
  /// stream, and forward audio under backwards picture is worse than silence.
  /// Declare an `Audio` track if a rewind needs sound. Positive scalar and
  /// ramp speeds retime embedded audio on desktop, browser and native encoders.
  final double speed;

  /// Optional positive keyframed playback rate. The shared integrated source
  /// clock keeps picture, extraction and embedded audio synchronized.
  final KeyframedNumber? speedRamp;

  @override
  Widget build(BuildContext context) {
    final Widget painted = ClipPainter(
      source: source,
      trim: trim,
      fit: fit,
      poster: poster,
      speed: speed,
      speedRamp: speedRamp,
    );
    return wrapShared(shared, painted);
  }
}

/// Whether [speed] is a rate a clip can actually play at.
///
/// Zero advances no source frames, so it is a still rather than a clip; a
/// non-finite rate cannot be resampled or staged into `atempo` at all.
bool _isRate(double speed) => speed != 0 && speed.isFinite;

/// The message both the widget assert and the spec decoder report, so a rate
/// refused in Dart reads the same as one refused in a document.
const String _rateMessage =
    'A clip speed is a non-zero, finite rate: 1 is source speed, 0.5 half, '
    '2 double, and a negative rate plays the trim backwards.';
