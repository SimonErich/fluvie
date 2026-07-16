import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:obers_ui/obers_ui.dart' show OiUndoAction, OiUndoStack;

/// The document plus its past: dispatch commands, undo, redo.
///
/// Documents are immutable snapshots, so history is memento-shaped: each
/// entry holds the documents before and after one command. The entries live
/// on obers_ui's [OiUndoStack]; the editor's merge policy (a command's
/// `mergeKey`) rides its `groupId` + `merge` callback, so a drag's stream of
/// transforms coalesces into a single undo step that lands back on the
/// document before the drag.
final class DocumentHistory extends ChangeNotifier {
  /// Starts the history at [document].
  DocumentHistory(EditorDocument document, {int maxHistory = 100})
    : _document = document,
      _stack = OiUndoStack(maxHistory: maxHistory);

  final OiUndoStack _stack;
  EditorDocument _document;
  Set<String> _lastAffected = const {};

  /// The current document state.
  EditorDocument get document => _document;

  /// Whether an undo step exists.
  bool get canUndo => _stack.canUndo;

  /// Whether a redo step exists.
  bool get canRedo => _stack.canRedo;

  /// The label of the next undo, or null.
  String? get undoLabel => _stack.nextUndoLabel;

  /// The label of the next redo, or null.
  String? get redoLabel => _stack.nextRedoLabel;

  /// Applies [command] and records it as an undo step (coalescing runs of
  /// the same `mergeKey`).
  void dispatch(EditorCommand command) {
    final before = _document;
    final after = command.apply(before);
    _document = after;
    _stack.push(_entry(command, before, after));
    notifyListeners();
  }

  /// Undoes one step and returns the affected element ids (the shell
  /// re-selects them so the change is visible). Empty when there was
  /// nothing to undo.
  Set<String> undo() => _travel(canUndo, _stack.undo);

  /// Redoes one step and returns the affected element ids.
  Set<String> redo() => _travel(canRedo, _stack.redo);

  Set<String> _travel(bool possible, void Function() move) {
    if (!possible) return const {};
    _lastAffected = const {};
    move();
    notifyListeners();
    return _lastAffected;
  }

  OiUndoAction _entry(EditorCommand command, EditorDocument before, EditorDocument after) {
    final ids = command.affectedIds;
    void undoToBefore() {
      _document = before;
      _lastAffected = ids;
    }

    return OiUndoAction(
      label: command.label,
      execute: () {
        _document = after;
        _lastAffected = ids;
      },
      undo: undoToBefore,
      groupId: command.mergeKey,
      merge: command.mergeKey == null ? null : (next) => _coalesced(undoToBefore, next),
    );
  }

  /// The merged step redoes to the LATEST state but undoes to the state
  /// before the FIRST command of the run — and keeps doing so however long
  /// the run grows (the combinator carries the first undo forward).
  OiUndoAction _coalesced(void Function() undoToFirstBefore, OiUndoAction next) => OiUndoAction(
    label: next.label,
    execute: next.execute,
    undo: undoToFirstBefore,
    groupId: next.groupId,
    merge: (following) => _coalesced(undoToFirstBefore, following),
  );
}
