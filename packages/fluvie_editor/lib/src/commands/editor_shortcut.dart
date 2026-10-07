import 'package:flutter/foundation.dart' show defaultTargetPlatform, immutable;
import 'package:flutter/services.dart' show LogicalKeyboardKey, TargetPlatform;
import 'package:flutter/widgets.dart' show SingleActivator;

/// One keyboard binding of the command registry: the key, whether the
/// command modifier (Ctrl, Cmd on macOS) and Shift take part, and any
/// alternate keys that fire the same binding (Backspace next to Delete).
///
/// The binding is the single source of truth for its own display: [hint]
/// spells the chord the menus print and [activator] is the same chord for
/// the palette — so what the UI shows is exactly what [matches] fires on.
@immutable
final class EditorShortcut {
  /// Binds [trigger] (or any key of [also]) with the given modifiers.
  const EditorShortcut(
    this.trigger, {
    this.command = false,
    this.shift = false,
    this.also = const [],
    this.alternates = const [],
  });

  /// The key that fires this binding.
  final LogicalKeyboardKey trigger;

  /// Whether the command modifier is part of the chord. Ctrl and Cmd (meta)
  /// both count, matching the canvas's other chords.
  final bool command;

  /// Whether Shift is part of the chord.
  final bool shift;

  /// Alternate keys that fire the same binding (Backspace for Delete).
  final List<LogicalKeyboardKey> also;

  /// Alternate whole chords that fire the same binding under their own
  /// modifiers (Ctrl+Y beside Ctrl+Shift+Z for redo). [hint] and
  /// [activator] keep spelling the primary chord.
  final List<EditorShortcut> alternates;

  /// Whether a press of [key] under the given modifier state fires this
  /// binding. Modifiers match exactly: `]` never fires the `Ctrl+]` binding
  /// and the other way round. Each chord of [alternates] matches under its
  /// own modifiers.
  bool matches(LogicalKeyboardKey key, {required bool command, required bool shift}) =>
      ((key == trigger || also.contains(key)) && command == this.command && shift == this.shift) ||
      alternates.any((alternate) => alternate.matches(key, command: command, shift: shift));

  /// The human-readable chord ("Ctrl+Shift+G"), spelling Cmd on macOS.
  String get hint => [
    if (command)
      if (defaultTargetPlatform == TargetPlatform.macOS) 'Cmd' else 'Ctrl',
    if (shift) 'Shift',
    _label(trigger),
  ].join('+');

  /// The same chord as a [SingleActivator] — the palette's display form.
  SingleActivator get activator {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    return SingleActivator(trigger, control: command && !mac, meta: command && mac, shift: shift);
  }

  static String _label(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.delete ? 'Del' : key.keyLabel;
}
