import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _never() => false;
void _noop() {}

/// The undo/redo face a host lends the editor's command surfaces.
///
/// The canvas key path, the context menus, and the command palette all read
/// it through [historyActionsProvider] when they snapshot their
/// `CommandScope`, so every surface fires the same history the top bar's
/// buttons do. The default is inert: a viewer without a history simply
/// shows Undo and Redo disabled.
final class HistoryActions {
  /// Describes a history. Omitted members stay inert (disabled, no-op).
  const HistoryActions({
    this.canUndo = _never,
    this.canRedo = _never,
    this.undo = _noop,
    this.redo = _noop,
  });

  /// Whether an undo step exists right now (read per scope snapshot).
  final bool Function() canUndo;

  /// Whether a redo step exists right now.
  final bool Function() canRedo;

  /// Undoes one step.
  final VoidCallback undo;

  /// Redoes one step.
  final VoidCallback redo;
}

/// The history the mounted editor scope's command surfaces act on. The host
/// overrides it with its `DocumentHistory`-backed actions; the default is
/// the inert [HistoryActions].
final historyActionsProvider = Provider<HistoryActions>((ref) => const HistoryActions());
