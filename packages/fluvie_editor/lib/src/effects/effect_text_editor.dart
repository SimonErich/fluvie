import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show EffectSpec, buildEffect;
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:obers_ui/obers_ui.dart';

/// Commits a validated effect string and keeps parse failures next to it.
final class EffectTextEditor extends StatefulWidget {
  /// Edits [name] on [spec].
  const EffectTextEditor({
    required this.spec,
    required this.name,
    required this.onChanged,
    super.key,
  });

  /// The current effect declaration.
  final EffectSpec spec;

  /// The string parameter name.
  final String name;

  /// Receives the new value, or null to restore its default.
  final ValueChanged<String?> onChanged;
  @override
  State<EffectTextEditor> createState() => _EffectTextEditorState();
}

final class _EffectTextEditorState extends State<EffectTextEditor> {
  String? _error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorTextField(
        value: widget.spec.text(widget.name) ?? '',
        onChanged: (text) {
          final value = text.trim();
          try {
            final json = {...widget.spec.toJson()};
            if (value.isEmpty) {
              json.remove(widget.name);
            } else {
              json[widget.name] = value;
            }
            buildEffect(EffectSpec.fromJson(json));
            widget.onChanged(value.isEmpty ? null : value);
            setState(() => _error = null);
          } on Object catch (error) {
            setState(() => _error = error.toString());
          }
        },
      ),
      if (_error != null) Semantics(liveRegion: true, child: OiLabel.small(_error!)),
    ],
  );
}
