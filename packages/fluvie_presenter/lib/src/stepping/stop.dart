import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show CollectibleChildren, LocalMotionScope;
import 'package:fluvie_presenter/src/stepping/frame_rebase.dart';
import 'package:fluvie_presenter/src/stepping/step_scope.dart';
import 'package:fluvie_presenter/src/stepping/stop_state.dart';

/// Marks its children as a build step: hidden until the step is reached,
/// then revealed with their authored entrance playing from that moment.
///
/// This is the PowerPoint and reveal.js model. Content not wrapped in a
/// `Stop` is step 0 and plays on slide entry; each `Stop` becomes a later
/// step, in document order (or by [order] when given). A `Stop` carries no
/// animation of its own — the children's `.animate()` entrances are what
/// plays on reveal:
///
/// ```dart
/// Scene(duration: 8.seconds, children: [
///   Text('Always there'),
///   Stop(children: [bullet1.animate([Animation.slideFadeIn()])]),
///   Stop(children: [bullet2.animate([Animation.slideFadeIn()])]),
/// ]);
/// ```
///
/// Outside a presentation (a plain fluvie render or preview) a `Stop` is a
/// transparent passthrough: the same deck renders as a normal video with the
/// authored timeline. Because a revealed step resolves its animations
/// locally, elements inside a `Stop` cannot use cross-element or beat
/// triggers; the step compiler reports those at compile time.
final class Stop extends StatelessWidget implements CollectibleChildren {
  /// Marks [children] as one build step revealing together.
  const Stop({required this.children, this.order, super.key});

  /// The single-child convenience: `Stop(children: [child])`.
  Stop.single({required Widget child, int? order, Key? key})
    : this(children: [child], order: order, key: key);

  /// The content this step reveals, stacked like scene children.
  final List<Widget> children;

  /// Overrides the document-order position of this step. Two stops in one
  /// scene must not declare the same order.
  final int? order;

  @override
  Iterable<Widget> get collectibleChildren => children;

  @override
  Widget build(BuildContext context) => switch (StepScope.stateOf(context, this)) {
    // No presentation above (or an undiscovered stop): pass through, so a
    // plain fluvie render of the same deck shows everything as authored.
    null => _group(),
    HiddenStop() => const SizedBox.shrink(),
    RevealedStop(:final baseFrame, :final skipFrames) => FrameRebase(
      baseFrame: baseFrame,
      skipFrames: skipFrames,
      child: LocalMotionScope(child: _group()),
    ),
  };

  /// The children as the scene would stack them: a single child passes
  /// through untouched, several stack centered like sibling scene children.
  Widget _group() => children.length == 1
      ? children.single
      : Stack(alignment: Alignment.center, children: children);
}
