import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/transport/slide_transport.dart';

/// The editor's Space key, routed by context: with the timeline panel open
/// Space toggles the shared transport, with it closed Space steps the way a
/// presenter click would — seeking to the next landing of [stepBounds] and
/// asking for the next slide past the last one.
///
/// Space is contextual (like the canvas's tool letters), so it lives on
/// this dedicated key surface instead of the global command registry: the
/// widget wraps the whole editing surface and hears whatever key events
/// the focused descendant leaves unhandled. A focus inside a text editor
/// keeps typing spaces — the transport never steals from a field.
final class TransportKeys extends StatelessWidget {
  /// Wires Space over [child] onto [transport].
  const TransportKeys({
    required this.transport,
    required this.panelOpen,
    required this.stepBounds,
    required this.child,
    this.onAdvanceSlide,
    super.key,
  });

  /// The active slide's shared playhead.
  final SlideTransport transport;

  /// Whether the timeline panel is open — open means Space plays and
  /// pauses, closed means Space steps.
  final bool panelOpen;

  /// The active slide's step landings (see `slideStepBounds`), read lazily
  /// per press so edits never leave a stale ladder behind.
  final List<int> Function() stepBounds;

  /// Asks the owner to put the next slide on stage when a step runs past
  /// the last landing. Null makes the last landing the end of the line.
  final VoidCallback? onAdvanceSlide;

  /// The editing surface the key events bubble out of.
  final Widget child;

  /// Whether the primary focus sits inside a text editor — its Space is a
  /// space character, never transport input.
  static bool _editingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null && context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.space) return KeyEventResult.ignored;
    if (_editingText()) return KeyEventResult.ignored;
    if (panelOpen) {
      transport.toggle();
      return KeyEventResult.handled;
    }
    final frame = transport.frame;
    for (final bound in stepBounds()) {
      if (bound > frame) {
        transport.seek(bound);
        return KeyEventResult.handled;
      }
    }
    onAdvanceSlide?.call();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    includeSemantics: false,
    onKeyEvent: _onKeyEvent,
    child: child,
  );
}
