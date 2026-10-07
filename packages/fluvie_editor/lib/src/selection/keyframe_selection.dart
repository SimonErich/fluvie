import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:meta/meta.dart';

/// One selected keyframe stop: the element, which of its animations, and
/// the stop's index in that animation's `keyframes` list.
@immutable
final class SelectedKeyframe {
  /// Creates the selection.
  const SelectedKeyframe({required this.elementId, required this.animation, required this.stop});

  /// The element owning the keyframes animation.
  final String elementId;

  /// The animation's position in the element's `animate` list.
  final int animation;

  /// The stop's index in the `keyframes` list.
  final int stop;

  @override
  bool operator ==(Object other) =>
      other is SelectedKeyframe &&
      other.elementId == elementId &&
      other.animation == animation &&
      other.stop == stop;

  @override
  int get hashCode => Object.hash(SelectedKeyframe, elementId, animation, stop);

  @override
  String toString() => 'SelectedKeyframe($elementId, animation $animation, stop $stop)';
}

/// The selected keyframe diamond, or null — timeline diamond taps write
/// here; the timeline's highlight and the inspector's Keyframe section
/// watch it.
///
/// The selection rides the element selection: when the selected elements
/// stop holding the diamond's element (a click elsewhere, Escape, a
/// delete), the keyframe selection clears itself. Like the element
/// selection, it is deliberately not undoable.
final class KeyframeSelectionController extends Notifier<SelectedKeyframe?> {
  @override
  SelectedKeyframe? build() {
    ref.listen(selectionProvider, (_, next) {
      final selected = state;
      if (selected != null && !next.contains(selected.elementId)) state = null;
    });
    return null;
  }

  /// Selects [keyframe] (a diamond tap).
  ///
  /// A method rather than a setter to keep the `select`/`clear` verb pair
  /// [SelectionController] established.
  // ignore: use_setters_to_change_properties -- the selection vocabulary is select and clear
  void select(SelectedKeyframe keyframe) => state = keyframe;

  /// Empties the selection (a bar tap, a deleted stop).
  void clear() => state = null;
}

/// The keyframe selection for the mounted editor scope.
final keyframeSelectionProvider = NotifierProvider<KeyframeSelectionController, SelectedKeyframe?>(
  KeyframeSelectionController.new,
);
