import 'package:flutter/widgets.dart';
import 'package:fluvie_editor/src/inspector/inspector_sections.dart';
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:fluvie_editor/src/widgets/editor_tip.dart';
import 'package:obers_ui/obers_ui.dart';

/// The rows editor for a `Terminal`'s `lines` session: per row a cmd/out
/// kind select, the text, and — on cmd rows — the optional per-line prompt
/// override (empty removes it). Rows add, remove, and reorder; the session
/// never empties (the codec requires at least one line).
final class TerminalLinesSection extends StatelessWidget {
  /// Edits the `lines` of [element]; every change lands in [patch].
  const TerminalLinesSection({required this.element, required this.patch, super.key});

  /// The terminal element JSON.
  final Map<String, Object?> element;

  /// Applies a content patch to the element.
  final ElementPatch patch;

  List<Map<String, Object?>> get _lines => [
    for (final line in element['lines']! as List<Object?>) line! as Map<String, Object?>,
  ];

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    return Column(
      key: const ValueKey('terminal-lines'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) _row(lines, i),
        Row(
          children: [
            EditorTip(
              message: 'Add line',
              child: OiIconButton(
                icon: OiIcons.plus,
                semanticLabel: 'Add line',
                size: OiButtonSize.small,
                onTap: () => _write([
                  ...lines,
                  {'cmd': ''},
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(List<Map<String, Object?>> lines, int index) {
    final line = lines[index];
    final isCmd = line.containsKey('cmd');
    return Padding(
      key: ValueKey('terminal-line-$index'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: OiSelect<String>(
              key: ValueKey('line-kind-$index'),
              value: isCmd ? 'cmd' : 'out',
              options: const [
                OiSelectOption(value: 'cmd', label: 'cmd'),
                OiSelectOption(value: 'out', label: 'out'),
              ],
              onChanged: (next) {
                if (next == null || next == (isCmd ? 'cmd' : 'out')) return;
                _replace(lines, index, _switched(line, toCmd: next == 'cmd'));
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InspectorTextField(
              key: ValueKey('line-text-$index'),
              value: (line[isCmd ? 'cmd' : 'out'] as String?) ?? '',
              onChanged: (next) => _replace(lines, index, {...line, isCmd ? 'cmd' : 'out': next}),
            ),
          ),
          if (isCmd) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 48,
              child: InspectorTextField(
                key: ValueKey('line-prompt-$index'),
                value: (line['prompt'] as String?) ?? '',
                placeholder: r'$ ',
                onChanged: (next) => _replace(
                  lines,
                  index,
                  next.isEmpty ? ({...line}..remove('prompt')) : {...line, 'prompt': next},
                ),
              ),
            ),
          ],
          _tipButton(
            'Move up',
            OiIcons.arrowUp,
            'Move line $index up',
            index == 0 ? null : () => _swap(lines, index, index - 1),
          ),
          _tipButton(
            'Move down',
            OiIcons.arrowDown,
            'Move line $index down',
            index == lines.length - 1 ? null : () => _swap(lines, index, index + 1),
          ),
          _tipButton(
            'Remove line',
            OiIcons.trash,
            'Remove line $index',
            lines.length <= 1 ? null : () => _write([...lines]..removeAt(index)),
          ),
        ],
      ),
    );
  }

  Widget _tipButton(String message, IconData icon, String semanticLabel, VoidCallback? onTap) =>
      EditorTip(
        message: message,
        child: OiIconButton(
          icon: icon,
          semanticLabel: semanticLabel,
          size: OiButtonSize.small,
          onTap: onTap,
        ),
      );

  /// The line's kind flipped, text carried over. A prompt only makes sense
  /// on a cmd line, so switching to out drops it.
  Map<String, Object?> _switched(Map<String, Object?> line, {required bool toCmd}) {
    final text = (line['cmd'] ?? line['out'] ?? '') as String;
    if (toCmd) return {'cmd': text};
    return {'out': text};
  }

  void _replace(List<Map<String, Object?>> lines, int index, Map<String, Object?> line) =>
      _write([...lines]..[index] = line);

  void _swap(List<Map<String, Object?>> lines, int a, int b) {
    final copy = [...lines];
    copy[a] = lines[b];
    copy[b] = lines[a];
    _write(copy);
  }

  void _write(List<Map<String, Object?>> lines) => patch({'lines': lines});
}
