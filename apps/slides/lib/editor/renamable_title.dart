import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/fluvie_editor.dart' show InspectorTextField;
import 'package:obers_ui/obers_ui.dart';

/// The deck name in the top bar: double-click to rename inline.
final class RenamableTitle extends StatefulWidget {
  /// Shows [name]; a committed rename lands in [onRenamed].
  const RenamableTitle({required this.name, required this.onRenamed, super.key});

  /// The deck's current name.
  final String name;

  /// Receives the new name.
  final ValueChanged<String> onRenamed;

  @override
  State<RenamableTitle> createState() => _RenamableTitleState();
}

final class _RenamableTitleState extends State<RenamableTitle> {
  bool _editing = false;
  int _lastTapMs = 0;

  void _tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 350) {
      setState(() => _editing = true);
    }
    _lastTapMs = now;
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return InspectorTextField(
        value: widget.name,
        onChanged: (next) {
          setState(() => _editing = false);
          if (next.trim().isNotEmpty) widget.onRenamed(next.trim());
        },
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: OiLabel.bodyStrong(widget.name),
    );
  }
}
