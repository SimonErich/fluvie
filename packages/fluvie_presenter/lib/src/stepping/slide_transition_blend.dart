import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show Edge, Transition, TransitionKind;

/// Renders the presenter-level blend between two slides, mapped from the
/// authored [Transition].
///
/// A live presentation cannot replay the compositor's boundary blend — the
/// outgoing slide holds a stepped, held state the authored timeline never
/// had — so the presenter blends the two stages itself: crossFade fades the
/// incoming slide in, slide pushes it in from its edge, wipe uncovers it,
/// zoom scales the outgoing slide away. The authored kind, duration, and
/// ease all apply.
final class SlideTransitionBlend extends StatelessWidget {
  /// Blends [incoming] over [outgoing] as [progress] runs 0 → 1.
  const SlideTransitionBlend({
    required this.transition,
    required this.progress,
    required this.outgoing,
    required this.incoming,
    super.key,
  });

  /// The authored boundary transition being mapped.
  final Transition transition;

  /// The blend clock, 0 at the boundary and 1 when the incoming slide owns
  /// the stage.
  final Animation<double> progress;

  /// The held outgoing slide.
  final Widget outgoing;

  /// The incoming slide, already playing.
  final Widget incoming;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: progress, curve: transition.ease);
    return switch (transition.kind) {
      TransitionKind.cut => incoming,
      TransitionKind.crossFade => _over(FadeTransition(opacity: curved, child: incoming)),
      TransitionKind.slide => _over(
        SlideTransition(
          position: Tween<Offset>(
            begin: _edgeOffset(transition.from ?? Edge.right),
            end: Offset.zero,
          ).animate(curved),
          child: incoming,
        ),
      ),
      TransitionKind.wipe => _over(
        AnimatedBuilder(
          animation: curved,
          builder: (_, child) => ClipRect(
            clipper: _WipeClipper(
              reveal: curved.value,
              direction: transition.direction ?? Edge.right,
            ),
            child: child,
          ),
          child: incoming,
        ),
      ),
      TransitionKind.zoom => Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          incoming,
          ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.15).animate(curved),
            alignment: transition.into ?? Alignment.center,
            child: FadeTransition(
              opacity: Tween<double>(begin: 1, end: 0).animate(curved),
              child: outgoing,
            ),
          ),
        ],
      ),
    };
  }

  /// The common shape: the outgoing slide beneath, the animated incoming
  /// treatment above.
  Widget _over(Widget treated) => Stack(
    fit: StackFit.passthrough,
    alignment: Alignment.center,
    children: [outgoing, treated],
  );

  static Offset _edgeOffset(Edge edge) => switch (edge) {
    Edge.left => const Offset(-1, 0),
    Edge.right => const Offset(1, 0),
    Edge.top => const Offset(0, -1),
    Edge.bottom => const Offset(0, 1),
  };
}

/// Clips the incoming slide to the fraction [reveal] of its box, uncovering
/// it along [direction] — `Edge.right` uncovers left-to-right.
final class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper({required this.reveal, required this.direction});

  final double reveal;
  final Edge direction;

  @override
  Rect getClip(Size size) => switch (direction) {
    Edge.right => Rect.fromLTWH(0, 0, size.width * reveal, size.height),
    Edge.left => Rect.fromLTWH(size.width * (1 - reveal), 0, size.width * reveal, size.height),
    Edge.bottom => Rect.fromLTWH(0, 0, size.width, size.height * reveal),
    Edge.top => Rect.fromLTWH(0, size.height * (1 - reveal), size.width, size.height * reveal),
  };

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.reveal != reveal || oldClipper.direction != direction;
}
