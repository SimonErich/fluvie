import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected timeline bars, by bar id.
///
/// Deliberately separate from the canvas selection: selecting a bar selects a
/// span of time on a lane, selecting an element selects a thing on the canvas.
/// A razor acts on the first and an align on the second, and one set holding
/// both would let each apply where it cannot.
final class TimelineSelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// A click on [barId] (null for empty lane space). Plain clicks replace the
  /// selection; [additive] toggles one bar and leaves a miss alone.
  void click(String? barId, {bool additive = false}) {
    if (barId == null) {
      if (!additive) clear();
      return;
    }
    if (!additive) {
      state = {barId};
      return;
    }
    state = state.contains(barId) ? ({...state}..remove(barId)) : {...state, barId};
  }

  /// A finished marquee over [barIds]; [additive] extends instead of replacing.
  void marquee(Set<String> barIds, {bool additive = false}) =>
      state = additive ? {...state, ...barIds} : {...barIds};

  /// Replaces the selection wholesale.
  void select(Set<String> barIds) => state = {...barIds};

  /// Empties the selection.
  void clear() => state = const {};

  /// Drops bar ids the timeline no longer draws, so a verb can never act on a
  /// bar that left with the last rebuild.
  void prune(Set<String> exist) => state = {...state.where(exist.contains)};
}

/// The timeline selection for the mounted editor.
final timelineSelectionProvider = NotifierProvider<TimelineSelectionController, Set<String>>(
  TimelineSelectionController.new,
);

/// The declared lane new material lands on, independent of canvas selection.
final activeTimelineLaneProvider = NotifierProvider<ActiveTimelineLaneController, String?>(
  ActiveTimelineLaneController.new,
);

/// Stores the focused declared lane without mutating document history.
final class ActiveTimelineLaneController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Selects a lane identity, or clears the active lane.
  // ignore: use_setters_to_change_properties -- matches the selection controllers' select verb
  void select(String? id) => state = id;
}
