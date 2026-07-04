import 'package:flutter/widgets.dart'
    show BuildContext, Color, CustomPaint, Positioned, Rect, Stack, StatelessWidget, Widget;
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/core/anchor.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/render/spotlight_painter.dart';
import 'package:fluvie/src/elements/reveal/reveal_progress.dart';
import 'package:fluvie/src/elements/runtime/element_shared.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';
import 'package:fluvie/src/timing/time_scope_provider.dart';

/// The translucent black the spotlight dims the un-lit area with by default.
const Color _defaultDim = Color(0xB3000000);

/// Dims everything but a lit [region], focusing attention on it.
///
/// `Spotlight` wraps a [child] (the scene it darkens), so it implements
/// `CollectibleChildren` — a `MediaCarrier` nested in the child is gathered by
/// the collect pass before frame 0, never missed and thrown at capture (the
/// collect-pass guard). The dim is a single even-odd `CustomPaint` fill that
/// punches a rounded hole over [region]; it never uses a `BackdropFilter` or
/// `saveLayer`, so it stays capture-safe. Over its [reveal] the hole grows
/// from nothing to the full [region], so the spotlight opens.
///
/// This ships the explicit-position form (a [Rect] [region]); resolving an
/// anchor to a rect is not yet supported.
///
/// ```dart
/// Spotlight.on(
///   region: const Rect.fromLTWH(120, 60, 280, 160),
///   reveal: 12.frames,
///   child: Image.asset('dashboard.png'),
/// );
/// ```
///
/// The dim [color] defaults to a translucent black. Transforms and effects ride
/// `.animate()` only. [shared] wraps the result in a `SharedElement` for a hero
/// morph across a scene boundary.
///
/// Two durations can meet here: [reveal] times the intrinsic dim-in,
/// while transforms and opacity ride `.animate()` with their own timing.
final class Spotlight extends StatelessWidget implements CollectibleChildren {
  /// Lights [region] over [child], dimming the rest, with the hole grown by the
  /// optional [reveal].
  const Spotlight.on({
    required this.region,
    required this.child,
    this.reveal,
    this.color = _defaultDim,
    this.shared,
    super.key,
  });

  /// The lit rect kept clear of the dim.
  final Rect region;

  /// The scene the spotlight dims (rendered behind the dim).
  final Widget child;

  /// The hole-grow reveal window resolved against the element scope, or `null`
  /// to open the full region at every frame.
  final Time? reveal;

  /// The color the dimmed area is filled with.
  final Color color;

  /// An optional hero anchor: when non-null the spotlight morphs across the
  /// boundary it shares with the same anchor in the adjacent scene. `null`
  /// mounts no `SharedElement`.
  final Anchor? shared;

  @override
  Iterable<Widget> get collectibleChildren => [child];

  @override
  Widget build(BuildContext context) {
    final painter = SpotlightPainter(
      region: region,
      reveal: _reveal(context),
      dimColor: color,
    );
    final stacked = Stack(
      children: [
        Positioned.fill(child: child),
        Positioned.fill(child: CustomPaint(painter: painter)),
      ],
    );
    return wrapShared(shared, stacked);
  }

  /// The hole-grow progress at this frame: `1` when there is no [reveal], else
  /// the shared reveal math resolved against the element scope.
  double _reveal(BuildContext context) {
    final window = reveal;
    if (window == null) return 1;
    final frame = FrameProvider.of(context).frame;
    return revealProgress(frame, TimeScopeProvider.of(context), window);
  }
}
