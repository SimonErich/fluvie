import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/shell/inspector_tabs.dart';
import 'package:obers_ui/obers_ui.dart';

/// Intrinsic-width inspector tabs that reveal programmatic and keyboard picks.
///
/// OiTabs has no selected-item scrolling/key hook. Keep this small strip owned
/// here, using OiTappable for pointer, keyboard activation and focus feedback.
final class InspectorTabStrip extends StatefulWidget {
  /// Displays [tabs] without squeezing their labels into equal-width slots.
  const InspectorTabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// The tabs available in the current workspace.
  final List<InspectorTab> tabs;

  /// The tab whose panel is currently visible.
  final InspectorTab selected;

  /// Called for pointer and keyboard navigation.
  final ValueChanged<InspectorTab> onSelected;

  @override
  State<InspectorTabStrip> createState() => _InspectorTabStripState();
}

final class _InspectorTabStripState extends State<InspectorTabStrip> {
  final Map<InspectorTab, GlobalKey> _labels = {
    for (final tab in InspectorTab.values) tab: GlobalKey(),
  };
  double? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal(widget.selected);
  }

  @override
  void didUpdateWidget(InspectorTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _reveal(widget.selected);
  }

  void _reveal(InspectorTab tab) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final label = _labels[tab]!.currentContext;
      if (label != null) Scrollable.ensureVisible(label, alignment: 0.5);
    });
  }

  void _select(InspectorTab tab) {
    widget.onSelected(tab);
    Focus.of(_labels[tab]!.currentContext!).requestFocus();
    _reveal(tab);
  }

  KeyEventResult _key(InspectorTab tab, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = widget.tabs.indexOf(tab);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight => rtl ? -1 : 1,
      LogicalKeyboardKey.arrowLeft => rtl ? 1 : -1,
      _ => 0,
    };
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.home => widget.tabs.first,
      LogicalKeyboardKey.end => widget.tabs.last,
      _ when direction != 0 => widget.tabs[(index + direction) % widget.tabs.length],
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    _select(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_width != constraints.maxWidth) {
        _width = constraints.maxWidth;
        _reveal(widget.selected);
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colors.borderSubtle)),
        ),
        child: SingleChildScrollView(
          key: const ValueKey('inspector-tab-strip'),
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (final tab in widget.tabs) _tab(context, tab)],
          ),
        ),
      );
    },
  );

  Widget _tab(BuildContext context, InspectorTab tab) {
    final selected = tab == widget.selected;
    final theme = context.components.tabs;
    final active = theme?.activeLabelColor ?? context.colors.primary.base;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) => _key(tab, event),
        child: OiTappable(
          semanticLabel: tab.label,
          onTap: () => _select(tab),
          onFocusChange: (focused) {
            if (focused) _reveal(tab);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: theme?.indicatorThickness ?? 2,
                  color: selected ? (theme?.indicatorColor ?? active) : const Color(0x00000000),
                ),
              ),
            ),
            child: Padding(
              padding:
                  theme?.tabPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ExcludeSemantics(
                child: Text(
                  tab.label,
                  key: _labels[tab],
                  maxLines: 1,
                  softWrap: false,
                  style: (theme?.labelStyle ?? const TextStyle(fontSize: 14)).copyWith(
                    color: selected
                        ? active
                        : (theme?.inactiveLabelColor ?? context.colors.textMuted),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
