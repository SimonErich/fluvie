import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/commands/command_registry.dart';
import 'package:fluvie_editor/src/commands/command_scope.dart';
import 'package:obers_ui/obers_ui.dart' show OiCommand, OiCommandBar, OiShortcutScope;

/// The registry as the palette shows it: every command enabled against
/// [scope], with its registered binding as the displayed shortcut.
///
/// Commands in [recentIds] (most recent first) get a priority boost, so
/// they float to the top of the empty-query list. [onExecuted] fires before
/// a command runs — the palette host records recency through it.
List<OiCommand> paletteCommands(
  CommandScope scope, {
  List<String> recentIds = const [],
  void Function(EditorCommandEntry entry)? onExecuted,
}) => [
  for (final entry in editorCommands)
    if (entry.enabled(scope))
      OiCommand(
        id: entry.id,
        label: entry.title,
        category: entry.category,
        shortcut: entry.shortcut?.activator,
        priority: recentIds.contains(entry.id) ? recentIds.length - recentIds.indexOf(entry.id) : 0,
        onExecute: () {
          onExecuted?.call(entry);
          unawaited(entry.execute(scope));
        },
      ),
];

/// The command palette host: mounts an [OiShortcutScope] over [child] so
/// Ctrl/Cmd+K opens an [OiCommandBar] of [paletteCommands], recents on top,
/// executing against the scope [scopeBuilder] snapshots at open.
final class EditorCommandPalette extends StatelessWidget {
  /// Hosts the palette over [child].
  const EditorCommandPalette({
    required this.scopeBuilder,
    required this.child,
    this.onDismissed,
    super.key,
  });

  /// Snapshots the current editing scope when the palette opens.
  final CommandScope Function() scopeBuilder;

  /// The surface the palette overlays.
  final Widget child;

  /// Called after the palette closes (the canvas re-takes focus).
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) => OiShortcutScope(
    child: _PaletteOverlay(scopeBuilder: scopeBuilder, onDismissed: onDismissed, child: child),
  );
}

final class _PaletteOverlay extends StatefulWidget {
  const _PaletteOverlay({
    required this.scopeBuilder,
    required this.onDismissed,
    required this.child,
  });

  final CommandScope Function() scopeBuilder;
  final VoidCallback? onDismissed;
  final Widget child;

  @override
  State<_PaletteOverlay> createState() => _PaletteOverlayState();
}

final class _PaletteOverlayState extends State<_PaletteOverlay> {
  ValueNotifier<bool>? _active;
  final List<String> _recentIds = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = OiShortcutScope.maybeOf(context)?.commandBarActive;
    if (next == _active) return;
    _active?.removeListener(_onActive);
    _active = next?..addListener(_onActive);
  }

  @override
  void dispose() {
    _active?.removeListener(_onActive);
    super.dispose();
  }

  void _onActive() => setState(() {});

  void _dismiss() {
    _active?.value = false;
    widget.onDismissed?.call();
  }

  void _recordRecent(EditorCommandEntry entry) {
    _recentIds
      ..remove(entry.id)
      ..insert(0, entry.id);
    if (_recentIds.length > 10) _recentIds.removeRange(10, _recentIds.length);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_active?.value ?? false)
        Positioned.fill(
          child: OiCommandBar(
            label: 'Command palette',
            commands: paletteCommands(
              widget.scopeBuilder(),
              recentIds: _recentIds,
              onExecuted: _recordRecent,
            ),
            onDismiss: _dismiss,
          ),
        ),
    ],
  );
}
