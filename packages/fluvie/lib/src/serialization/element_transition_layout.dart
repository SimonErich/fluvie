part of 'element_transition_spec.dart';

/// Effective clip windows and blends for one holding list.
final class ElementTransitionLayout {
  /// Creates immutable derived layout data.
  const ElementTransitionLayout(this.windows, this.blends);

  /// Element-local show bounds in parent-local frames.
  final Map<String, ({int start, int end})> windows;

  /// Each paired blend on the same parent clock.
  final List<ElementTransitionWindow> blends;
}
