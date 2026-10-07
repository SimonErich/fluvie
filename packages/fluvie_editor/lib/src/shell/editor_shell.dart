import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:obers_ui/obers_ui.dart';

/// The settings namespace the shell persists its layout under.
const String _shellSettingsNamespace = 'fluvie.editor.shell';

/// The editor's outer layout: a tool rail, a resizable three-column stage, and
/// a bottom band that spans the whole surface beside the rail.
///
/// The band is the point. A timeline's scarcest resource is horizontal pixels,
/// and trapping it inside the stage column costs it everything the left panel
/// and the inspector take. Splitting the surface horizontally instead gives it
/// the window's width, and one divider governs how the stage and the band
/// share the height.
///
/// Layout is *chrome*, never document data: nothing here reaches a render or a
/// digest. It persists through the injected [settings] driver so a reopened
/// editor looks the way it was left; with no driver the shell still lays out
/// and simply forgets, which is what a host with nowhere to write wants.
final class EditorShell extends StatefulWidget {
  /// Creates the shell around its slots.
  const EditorShell({
    required this.toolbar,
    required this.leftColumn,
    required this.stage,
    required this.inspector,
    required this.bottom,
    this.settings,
    this.onColumnWidths,
    this.initialStageRatio = 0.68,
    super.key,
  });

  /// The fixed tool rail, outside the split so it keeps the full height.
  final Widget toolbar;

  /// The left panel (slides, layers).
  final Widget leftColumn;

  /// The canvas column.
  final Widget stage;

  /// The right panel.
  final Widget inspector;

  /// The full-width band under the stage — the timeline and its neighbours,
  /// or null for a surface that has none.
  ///
  /// Master editing is the case that has none: it swaps the whole stage for a
  /// synthetic view with no timeline, and reserving a quarter of the height for
  /// an empty band would be worse than not splitting at all.
  final Widget? bottom;

  /// Where the layout is persisted, or null to lay out without remembering.
  final OiSettingsDriver? settings;

  /// Reports the left and right column widths after a resize, so a host can
  /// persist them alongside the split ratio.
  final void Function(double left, double right)? onColumnWidths;

  /// How much of the height the stage takes before anyone drags the divider.
  final double initialStageRatio;

  @override
  State<EditorShell> createState() => _EditorShellState();
}

final class _ColumnSettings with OiSettingsData {
  const _ColumnSettings(this.left, this.right);
  factory _ColumnSettings.fromJson(Map<String, dynamic> json) => _ColumnSettings(
    (json['left'] is num ? (json['left'] as num).toDouble() : 260.0).clamp(200.0, 400.0),
    (json['right'] is num ? (json['right'] as num).toDouble() : 320.0).clamp(250.0, 500.0),
  );
  final double left;
  final double right;
  @override
  int get schemaVersion => 1;
  @override
  Map<String, dynamic> toJson() => {'schemaVersion': 1, 'left': left, 'right': right};
}

final class _EditorShellState extends State<EditorShell> {
  _ColumnSettings _widths = const _ColumnSettings(260, 320);
  int _loaded = 0;
  bool _resized = false;
  Future<void> _saving = Future.value();
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final stored = await widget.settings?.load<_ColumnSettings>(
        namespace: _shellSettingsNamespace,
        key: 'columns',
        deserialize: _ColumnSettings.fromJson,
      );
      if (mounted && stored != null && !_resized) {
        setState(() {
          _widths = stored;
          _loaded++;
        });
      }
    } on Object {
      /* Optional layout persistence must not prevent editing. */
    }
  }

  void _resize(double left, double right) {
    _resized = true;
    final value = _widths = _ColumnSettings(left, right);
    widget.onColumnWidths?.call(left, right);
    // Serial writes preserve the last drag position even on a slow driver.
    _saving = _saving.then((_) async {
      try {
        await widget.settings?.save<_ColumnSettings>(
          namespace: _shellSettingsNamespace,
          key: 'columns',
          data: value,
          serialize: (value) => value.toJson(),
        );
      } on Object {
        /* Keep the working layout when persistence is unavailable. */
      }
    });
  }

  Widget _columns() => OiThreeColumnLayout(
    key: ValueKey(_loaded),
    label: 'Editor',
    leftColumn: widget.leftColumn,
    middleColumn: widget.stage,
    rightColumn: widget.inspector,
    leftColumnWidth: _widths.left,
    rightColumnWidth: _widths.right,
    onColumnWidthChanged: _resize,
  );

  @override
  Widget build(BuildContext context) {
    final band = widget.bottom;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.toolbar,
        Expanded(
          child: band == null
              ? _columns()
              : OiSplitPane(
                  direction: Axis.vertical,
                  initialRatio: widget.initialStageRatio,
                  minRatio: 0.25,
                  settingsDriver: widget.settings,
                  settingsKey: 'stage-split',
                  leading: _columns(),
                  trailing: EditorShellBottomBand(child: band),
                ),
        ),
      ],
    );
  }
}

/// The shell's full-width band, named so a test can measure it and a reader
/// can find what spans the surface.
final class EditorShellBottomBand extends StatelessWidget {
  /// Wraps [child] as the band.
  const EditorShellBottomBand({required this.child, super.key});

  /// The band's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: child);
}

/// The namespace the shell writes its layout under, exposed so a host can
/// clear it (a "reset layout" action) without guessing the string.
String get editorShellSettingsNamespace => _shellSettingsNamespace;
