import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart'
    show OiBuildContextThemeExt, OiFloating, OiFloatingAlignment, OiLabel;

// obers_ui upstream candidate: a hover tooltip that leaves the child's
// semantics untouched (OiTooltip wraps a Semantics label around its child,
// which swallows the descendant's own label).

/// A hover tooltip: shows [message] after a short delay, purely visually —
/// the child keeps its own semantics label.
final class EditorTip extends StatefulWidget {
  /// Shows [message] over [child] after [delay] of hover.
  const EditorTip({
    required this.message,
    required this.child,
    this.delay = const Duration(milliseconds: 500),
    super.key,
  });

  /// The tooltip text (name plus shortcut).
  final String message;

  /// The control being explained.
  final Widget child;

  /// The hover delay before showing.
  final Duration delay;

  @override
  State<EditorTip> createState() => _EditorTipState();
}

final class _EditorTipState extends State<EditorTip> {
  Timer? _timer;
  bool _visible = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  void _hide() {
    _timer?.cancel();
    if (_visible) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OiFloating(
      visible: _visible,
      alignment: OiFloatingAlignment.topCenter,
      gap: 6,
      anchor: MouseRegion(
        onEnter: (_) => _schedule(),
        onExit: (_) => _hide(),
        child: widget.child,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: OiLabel.small(widget.message),
        ),
      ),
    );
  }
}
