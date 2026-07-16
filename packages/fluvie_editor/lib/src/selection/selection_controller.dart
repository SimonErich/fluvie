import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The selected element ids — canvas clicks, the marquee, the layers panel,
/// and undo re-selection all write here; chrome and the inspector watch it.
///
/// Selection is deliberately not undoable (the Figma convention): history
/// re-selects a command's affected ids instead.
final class SelectionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// A canvas click on [id] (null for empty canvas). Plain clicks replace
  /// the selection; [additive] (shift) toggles membership.
  void click(String? id, {bool additive = false}) {
    if (id == null) {
      if (!additive) clear();
      return;
    }
    if (!additive) {
      state = {id};
      return;
    }
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
  }

  /// A finished marquee over [ids]; [additive] extends instead of replacing.
  void marquee(Set<String> ids, {bool additive = false}) {
    state = additive ? {...state, ...ids} : {...ids};
  }

  /// Replaces the selection wholesale (undo and the layers panel use this).
  void select(Set<String> ids) => state = {...ids};

  /// Empties the selection (Escape, empty-canvas click).
  void clear() => state = const {};

  /// Drops selected ids that no longer [exist] in the document.
  void prune(Set<String> exist) => state = {...state.where(exist.contains)};
}

/// The selection for the mounted editor scope.
final selectionProvider = NotifierProvider<SelectionController, Set<String>>(
  SelectionController.new,
);
