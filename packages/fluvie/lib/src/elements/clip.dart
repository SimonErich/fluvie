import 'package:flutter/widgets.dart' show BoxFit, BuildContext, StatelessWidget, Widget;
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
/// A renderer must turn the source video into deterministic pixels *before*
/// capture: Fluvie probes the clip and pre-extracts its needed frames in the
/// pre-resolve pass, then paints the right one synchronously per composition
/// frame. The composition frame is mapped to a source frame by the
/// floor-resampling rule, so a slow source under a fast composition holds frames
/// instead of skipping. A capture with no pre-resolution throws a
/// `FluvieRenderException` naming the source; a live preview paints a
/// placeholder, where determinism does not bind.
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
final class Clip extends StatelessWidget implements MediaCarrier {
  /// A bundled video addressed by its asset key [name]
  /// (for example `fixtures/clip_1s.mp4`).
  Clip.asset(
    String name, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    super.key,
  }) : source = MediaSource.asset(name);

  /// A remote video at [url]; only allowlisted hosts and schemes are fetched in
  /// capture.
  Clip.network(
    Uri url, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    super.key,
  }) : source = MediaSource.network(url);

  /// A video file on disk at [path] (must end in `.mp4`/`.mov`/`.webm` so the
  /// clip path recognizes it). For a scoped-storage source the caller copies it
  /// to a readable app-private path first.
  Clip.file(
    String path, {
    this.trim,
    this.audio = const ClipAudio.included(),
    this.shared,
    this.fit,
    super.key,
  }) : source = MediaSource.file(path);

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

  @override
  Widget build(BuildContext context) {
    final Widget painted = ClipPainter(source: source, trim: trim, fit: fit);
    return wrapShared(shared, painted);
  }
}
