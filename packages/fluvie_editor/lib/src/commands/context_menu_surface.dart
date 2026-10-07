part of 'context_menu_host.dart';

/// The menu panel: a positioned column of item rows, clamped to the
/// overlay's bounds. A row with children drills down into them (the host's
/// minimal take on submenus); Escape and the barrier close the menu.
final class _MenuSurface extends StatefulWidget {
  const _MenuSurface({required this.position, required this.items, required this.onClose});

  final Offset position;
  final List<OiMenuItem> items;
  final VoidCallback onClose;

  @override
  State<_MenuSurface> createState() => _MenuSurfaceState();
}

final class _MenuSurfaceState extends State<_MenuSurface> {
  List<OiMenuItem>? _drilled;

  void _activate(OiMenuItem item) {
    if (!item.enabled) return;
    final children = item.children;
    if (children != null && children.isNotEmpty) {
      setState(() => _drilled = children);
      return;
    }
    widget.onClose();
    item.onTap?.call();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _drilled ?? widget.items;
    return CustomSingleChildLayout(
      delegate: _MenuLayoutDelegate(widget.position),
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderSubtle),
            boxShadow: [
              BoxShadow(color: colors.overlay, blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicWidth(
            // A menu taller than the overlay scrolls instead of overflowing.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items)
                    if (item is OiMenuDivider)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ColoredBox(
                          color: colors.borderSubtle,
                          child: const SizedBox(height: 1, width: double.infinity),
                        ),
                      )
                    else
                      _MenuRow(item: item, onActivate: () => _activate(item)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled row: check mark, label, shortcut hint, submenu chevron.
/// Deliberately not `OiTappable` — that requires OiApp's platform scope,
/// and this host must also run over a bare [Overlay].
final class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.item, required this.onActivate});

  final OiMenuItem item;
  final VoidCallback onActivate;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

final class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final item = widget.item;
    final textColor = !item.enabled
        ? colors.textMuted
        : item.destructive
        ? colors.error.base
        : colors.text;
    final hasChildren = item.children != null && item.children!.isNotEmpty;
    return Semantics(
      button: true,
      enabled: item.enabled,
      label: item.semanticLabel ?? item.label,
      child: MouseRegion(
        cursor: item.enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: item.enabled ? widget.onActivate : null,
          child: ColoredBox(
            color: _hovered && item.enabled ? colors.surfaceHover : const Color(0x00000000),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _rowContent(colors, textColor, hasChildren),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowContent(OiColorScheme colors, Color textColor, bool hasChildren) {
    final item = widget.item;
    return Row(
      children: [
        if (item.checked != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: item.checked!
                ? OiIcon.decorative(icon: OiIcons.check, size: 14, color: textColor)
                : const SizedBox(width: 14),
          ),
        OiLabel.body(item.label, color: textColor),
        const Spacer(),
        if (item.shortcut != null)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: OiLabel.small(item.shortcut!, color: colors.textMuted),
          ),
        if (hasChildren)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: OiIcon.decorative(icon: OiIcons.chevronRight, size: 14, color: colors.textMuted),
          ),
      ],
    );
  }
}

/// Anchors the panel at the press position, clamped inside the overlay.
final class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  const _MenuLayoutDelegate(this.position);

  final Offset position;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    position.dx.clamp(0, max(0, size.width - childSize.width)),
    position.dy.clamp(0, max(0, size.height - childSize.height)),
  );

  @override
  bool shouldRelayout(covariant _MenuLayoutDelegate oldDelegate) =>
      oldDelegate.position != position;
}
