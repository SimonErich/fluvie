import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:fluvie/fluvie.dart' show EffectSpec, buildEffect;
import 'package:fluvie_editor/src/inspector/inspector_text_field.dart';
import 'package:obers_ui/obers_ui.dart';

/// A validated editor for extensible structured parameters. Commits only on
/// Apply, and keeps invalid text visible with its parse error for correction.
final class EffectObjectEditor extends StatefulWidget {
  /// Edits one structured field of an effect.
  const EffectObjectEditor({
    required this.spec,
    required this.name,
    required this.onChanged,
    super.key,
  });

  /// The effect whose structured field is being edited.
  final EffectSpec spec;

  /// The object parameter name.
  final String name;

  /// Receives only validated object drafts.
  final ValueChanged<Map<String, Object?>> onChanged;
  @override
  State<EffectObjectEditor> createState() => _EffectObjectEditorState();
}

final class _EffectObjectEditorState extends State<EffectObjectEditor> {
  String? _draft;
  String? _error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OiLabel.small(
        widget.name == 'uniforms'
            ? 'Uniforms (named numeric values, in shader order)'
            : 'Particle settings',
      ),
      if (widget.name == 'particles')
        Wrap(
          spacing: 4,
          children: [
            for (final kind in ['sparkle', 'confetti', 'snow'])
              OiButton.ghost(
                label: kind,
                onTap: () {
                  setState(() {
                    _draft = null;
                    _error = null;
                  });
                  widget.onChanged({'kind': kind});
                },
              ),
          ],
        ),
      InspectorTextField(
        key: ValueKey('effect-object-${widget.name}'),
        value:
            _draft ??
            const JsonEncoder.withIndent('  ').convert(
              widget.spec.object(widget.name) ??
                  (widget.name == 'particles' ? {'kind': 'sparkle'} : {}),
            ),
        maxLines: 7,
        onEdited: (text) => _draft = text,
        onChanged: (text) => _draft = text,
      ),
      if (_error != null)
        Semantics(liveRegion: true, child: OiLabel.small(_error!, color: context.colors.text)),
      OiButton.ghost(
        label: 'Apply ${widget.name}',
        onTap: () {
          try {
            final raw = jsonDecode(
              _draft ??
                  jsonEncode(
                    widget.spec.object(widget.name) ??
                        (widget.name == 'particles' ? {'kind': 'sparkle'} : {}),
                  ),
            );
            if (raw is! Map<String, Object?>) throw const FormatException('Expected a JSON object');
            buildEffect(EffectSpec.fromJson({...widget.spec.toJson(), widget.name: raw}));
            widget.onChanged(raw);
            setState(() {
              _draft = null;
              _error = null;
            });
          } on Object catch (error) {
            setState(() => _error = error.toString());
          }
        },
      ),
    ],
  );
}
