import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

void main() {
  group('EditorShortcut', () {
    test('matches its trigger with exact modifiers', () {
      const shortcut = EditorShortcut(LogicalKeyboardKey.keyG, command: true);
      expect(shortcut.matches(LogicalKeyboardKey.keyG, command: true, shift: false), isTrue);
      expect(shortcut.matches(LogicalKeyboardKey.keyG, command: false, shift: false), isFalse);
      expect(shortcut.matches(LogicalKeyboardKey.keyG, command: true, shift: true), isFalse);
      expect(shortcut.matches(LogicalKeyboardKey.keyH, command: true, shift: false), isFalse);
    });

    test('a bare-key binding refuses modified presses', () {
      const shortcut = EditorShortcut(LogicalKeyboardKey.bracketRight);
      expect(
        shortcut.matches(LogicalKeyboardKey.bracketRight, command: false, shift: false),
        isTrue,
      );
      expect(
        shortcut.matches(LogicalKeyboardKey.bracketRight, command: true, shift: false),
        isFalse,
      );
    });

    test('alternate triggers fire the same binding', () {
      const shortcut = EditorShortcut(
        LogicalKeyboardKey.delete,
        also: [LogicalKeyboardKey.backspace],
      );
      expect(shortcut.matches(LogicalKeyboardKey.delete, command: false, shift: false), isTrue);
      expect(shortcut.matches(LogicalKeyboardKey.backspace, command: false, shift: false), isTrue);
      expect(shortcut.matches(LogicalKeyboardKey.keyX, command: false, shift: false), isFalse);
    });

    test('alternate whole chords fire under their own modifiers', () {
      const shortcut = EditorShortcut(
        LogicalKeyboardKey.keyZ,
        command: true,
        shift: true,
        alternates: [EditorShortcut(LogicalKeyboardKey.keyY, command: true)],
      );
      expect(shortcut.matches(LogicalKeyboardKey.keyZ, command: true, shift: true), isTrue);
      expect(shortcut.matches(LogicalKeyboardKey.keyY, command: true, shift: false), isTrue);
      // Each chord keeps its own exact modifiers.
      expect(shortcut.matches(LogicalKeyboardKey.keyY, command: true, shift: true), isFalse);
      expect(shortcut.matches(LogicalKeyboardKey.keyZ, command: true, shift: false), isFalse);
    });

    test('the hint spells the primary chord, alternates stay silent', () {
      const shortcut = EditorShortcut(
        LogicalKeyboardKey.keyZ,
        command: true,
        shift: true,
        alternates: [EditorShortcut(LogicalKeyboardKey.keyY, command: true)],
      );
      expect(shortcut.hint, 'Ctrl+Shift+Z');
      expect(shortcut.activator.trigger, LogicalKeyboardKey.keyZ);
    });

    test('the hint spells the chord', () {
      expect(const EditorShortcut(LogicalKeyboardKey.keyC, command: true).hint, 'Ctrl+C');
      expect(
        const EditorShortcut(LogicalKeyboardKey.keyG, command: true, shift: true).hint,
        'Ctrl+Shift+G',
      );
      expect(const EditorShortcut(LogicalKeyboardKey.bracketLeft).hint, '[');
      expect(const EditorShortcut(LogicalKeyboardKey.delete).hint, 'Del');
    });

    test('the activator mirrors the chord for display', () {
      const shortcut = EditorShortcut(LogicalKeyboardKey.keyG, command: true, shift: true);
      final activator = shortcut.activator;
      expect(activator.trigger, LogicalKeyboardKey.keyG);
      expect(activator.control, isTrue);
      expect(activator.meta, isFalse);
      expect(activator.shift, isTrue);
    });

    test('macOS spells Cmd and activates meta', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const shortcut = EditorShortcut(LogicalKeyboardKey.keyC, command: true);
      expect(shortcut.hint, 'Cmd+C');
      expect(shortcut.activator.meta, isTrue);
      expect(shortcut.activator.control, isFalse);
    });
  });
}
