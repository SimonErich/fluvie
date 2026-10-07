import 'dart:math' show max;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

part 'context_menu_surface.dart';

/// Opens a context menu over a drag-heavy surface without entering the
/// gesture arena.
///
/// `OiContextMenu` detects right-clicks with its own `GestureDetector`,
/// whose long-press recognizer joins every pointer's arena — on the canvas
/// that competition swallows the first motion of a one-jump drag (E16's
/// arena gotcha). This host listens to raw pointer events instead (raw
/// listeners never compete) and renders the same `OiMenuItem`s through
/// `OiOverlays`, with the item list chosen at open time from the press
/// position — so the menu's target is the element actually under the
/// pointer, hover or not.
// obers_ui upstream candidate: OiContextMenu.showAt(position, items) or an
// arena-free detection mode would let the canvas adopt it directly.
final class ContextMenuHost extends StatefulWidget {
  /// Listens over [child] and opens the items [itemsAt] returns for the
  /// pressed position.
  const ContextMenuHost({
    required this.label,
    required this.itemsAt,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// The accessible label for the menu overlay.
  final String label;

  /// Builds the menu for a right-click at a local position; an empty list
  /// opens nothing.
  final List<OiMenuItem> Function(Offset local) itemsAt;

  /// Whether right-clicks open the menu (a drag session disables it).
  final bool enabled;

  /// The surface the menu listens over.
  final Widget child;

  @override
  State<ContextMenuHost> createState() => _ContextMenuHostState();
}

final class _ContextMenuHostState extends State<ContextMenuHost> {
  OiOverlayHandle? _handle;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled || event.buttons & kSecondaryButton == 0) return;
    _close();
    final items = widget.itemsAt(event.localPosition);
    if (items.isEmpty) return;
    _show(event.position, items);
  }

  void _show(Offset globalPosition, List<OiMenuItem> items) {
    final surface = _MenuSurface(position: globalPosition, items: items, onClose: _close);
    final overlays = OiOverlays.maybeOf(context);
    if (overlays != null) {
      _handle = overlays.show(
        label: widget.label,
        zOrder: OiOverlayZOrder.dropdown,
        dismissOnScroll: true,
        onDismiss: _close,
        builder: (_) => surface,
      );
      return;
    }
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Semantics(
        label: widget.label,
        scopesRoute: true,
        explicitChildNodes: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _close(),
              ),
            ),
            surface,
          ],
        ),
      ),
    );
    overlay.insert(entry);
    _handle = createOiOverlayHandle(entry);
  }

  void _close() {
    final handle = _handle;
    _handle = null;
    handle?.dismiss();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _onPointerDown,
    child: widget.child,
  );
}
