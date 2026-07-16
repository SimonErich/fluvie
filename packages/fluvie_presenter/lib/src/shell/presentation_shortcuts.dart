import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

part 'presenter_handlers.dart';

/// One input surface for the whole presenter: keyboard (including what
/// presenter remotes send), tap, and swipe, mapped to [PresenterHandlers].
///
/// The bindings follow Keynote and reveal.js muscle memory: arrows, Space,
/// PageUp/PageDown (remotes), Enter, Home/End, digits-then-Enter to jump,
/// F/F5 for fullscreen (remotes send F5 to start), Esc, O for overview, S
/// for the speaker window, B or period for black, W for white, H for the
/// HUD, T for the sidebar, N for the notes panel. Tap advances; swiping
/// left advances and swiping right goes back.
///
/// The widget grabs focus on mount so keys work immediately on load — on
/// the web too, where focus otherwise sits on the page body.
///
/// Deliberately one `Focus.onKeyEvent` switch rather than Flutter's
/// `Shortcuts`/`Actions` tables: the digit-then-Enter jump buffer and the
/// Shift+Space chord are stateful across key events, which an intent table
/// cannot express without a side channel. One switch keeps the whole map
/// readable in one place.
final class PresentationShortcuts extends StatefulWidget {
  /// Wires the input surface around [child].
  const PresentationShortcuts({required this.handlers, required this.child, super.key});

  /// What the inputs do.
  final PresenterHandlers handlers;

  /// The stage being presented.
  final Widget child;

  @override
  State<PresentationShortcuts> createState() => _PresentationShortcutsState();
}

final class _PresentationShortcutsState extends State<PresentationShortcuts> {
  /// Typed digits awaiting Enter — the jump buffer.
  final StringBuffer _digits = StringBuffer();

  // Not const: LogicalKeyboardKey has no primitive equality.
  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final handlers = widget.handlers;
    final key = event.logicalKey;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    final digit = _digitKeys[key];
    if (digit != null) {
      _digits.write(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _commitJumpOr(handlers.onNext);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_digits.isNotEmpty) {
        _digits.clear();
      } else {
        handlers.onEscape();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      (shift ? handlers.onBack : handlers.onNext)();
      return KeyEventResult.handled;
    }

    final action = switch (key) {
      LogicalKeyboardKey.arrowRight ||
      LogicalKeyboardKey.arrowDown ||
      LogicalKeyboardKey.pageDown => handlers.onNext,
      LogicalKeyboardKey.arrowLeft ||
      LogicalKeyboardKey.arrowUp ||
      LogicalKeyboardKey.pageUp => handlers.onBack,
      LogicalKeyboardKey.home => handlers.onFirst,
      LogicalKeyboardKey.end => handlers.onLast,
      LogicalKeyboardKey.keyF || LogicalKeyboardKey.f5 => handlers.onToggleFullscreen,
      LogicalKeyboardKey.keyO => handlers.onOverview,
      LogicalKeyboardKey.keyS => handlers.onSpeakerWindow,
      LogicalKeyboardKey.keyB || LogicalKeyboardKey.period => handlers.onBlackScreen,
      LogicalKeyboardKey.keyW => handlers.onWhiteScreen,
      LogicalKeyboardKey.keyH => handlers.onToggleHud,
      LogicalKeyboardKey.keyT => handlers.onToggleSidebar,
      LogicalKeyboardKey.keyN => handlers.onToggleNotes,
      _ => null,
    };
    if (action == null) return KeyEventResult.ignored;
    action();
    return KeyEventResult.handled;
  }

  /// Enter is two keys in one: it commits a pending digit jump, otherwise it
  /// advances.
  void _commitJumpOr(VoidCallback advance) {
    if (_digits.isEmpty) {
      advance();
      return;
    }
    final number = int.parse(_digits.toString());
    _digits.clear();
    // Presented numbers are one-based; index zero-based. "0" clamps below.
    widget.handlers.onJump(number - 1);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) widget.handlers.onNext();
    if (velocity > 200) widget.handlers.onBack();
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _onKeyEvent,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.handlers.onNext,
      onHorizontalDragEnd: _onSwipe,
      child: widget.child,
    ),
  );
}
