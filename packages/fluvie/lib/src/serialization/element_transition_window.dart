part of 'element_transition_spec.dart';

/// Resolved timing of a single clip transition, on its parent group's clock.
final class ElementTransitionWindow {
  /// Creates a blend window over [outgoing] and [incoming].
  const ElementTransitionWindow({
    required this.outgoing,
    required this.incoming,
    required this.start,
    required this.end,
    required this.transition,
    this.holdFrame,
  });

  /// Outgoing element identity.
  final String outgoing;

  /// Incoming element identity.
  final String incoming;

  /// Inclusive first blend frame on the parent clock.
  final int start;

  /// Exclusive blend end.
  final int end;

  /// Strategy and easing for this pair.
  final Transition transition;

  /// Final outgoing picture frame for non-overlap, null during live overlap.
  final int? holdFrame;

  /// Whether the current parent-local frame lies in the blend.
  bool contains(int frame) => frame >= start && frame < end;

  /// Progress follows scene transitions: the first frame advances one sample.
  double progressAt(int frame) => ((frame - start + 1) / (end - start)).clamp(0.0, 1.0);
}
