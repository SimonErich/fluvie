import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show CubeLut;
import 'package:fluvie_editor/src/colour/colour_looks.dart';
import 'package:fluvie_editor/src/colour/colour_scopes.dart';
import 'package:fluvie_editor/src/commands/editor_clipboard.dart';
import 'package:fluvie_editor/src/document/editor_command.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/effects/effects_section.dart';
import 'package:fluvie_editor/src/selection/selection_controller.dart';
import 'package:fluvie_editor/src/widgets/math_number_input.dart';
import 'package:obers_ui/obers_ui.dart';

part 'colour_grade_actions.dart';

/// Colour authoring, curated Looks and scopes of the actual preview frame.
final class ColourPanel extends ConsumerStatefulWidget {
  /// The host imports LUT text; the panel validates and embeds it in the spec.
  const ColourPanel({
    required this.document,
    required this.onCommand,
    this.playheadProgress,
    this.onImportLut,
    this.scopes,
    super.key,
  });

  /// The current immutable document.
  final EditorDocument document;

  /// Dispatches edits into the document history.
  final ValueChanged<EditorCommand> onCommand;

  /// The playhead position inside an element, for keyframe conversion.
  final double? Function(String)? playheadProgress;

  /// Imports bounded .cube text; null means the host has no file picker.
  final Future<String?> Function()? onImportLut;

  /// Read-only scopes from the host canvas.
  final ColourScopesController? scopes;
  @override
  ConsumerState<ColourPanel> createState() => _ColourPanelState();
}

final class _ColourPanelState extends ConsumerState<ColourPanel> {
  double _intensity = 0.6;
  String? _message;
  bool _importing = false;

  List<Map<String, Object?>> _grade(String id) => [
    for (final effect in widget.document.elementJson(id)?['effects'] as List? ?? const [])
      if (colourEffectKinds.contains((effect as Map)['kind'])) effect.cast<String, Object?>(),
  ];

  void _applyLook(ColourLook look, List<String> selected) => widget.onCommand(
    ApplyColourCommand(ids: selected, effects: look.at(_intensity), name: look.name),
  );

  Future<void> _copy(List<String> selected) async {
    await ref
        .read(editorClipboardProvider)
        .write(ClipboardEnvelope.effects(_grade(selected.first)));
    if (mounted) setState(() => _message = 'Grade copied.');
  }

  Future<void> _paste(List<String> ids) async {
    final envelope = await ref.read(editorClipboardProvider).read();
    if (!mounted) return;
    final effects = envelope?.effects.where((e) => colourEffectKinds.contains(e['kind'])).toList();
    if (effects == null || effects.isEmpty) {
      setState(() => _message = 'Copy a grade first.');
      return;
    }
    widget.onCommand(ApplyColourCommand(ids: ids, effects: effects, name: 'copied grade'));
    setState(() => _message = 'Grade applied to ${ids.length} elements.');
  }

  List<String> _laneIds(String id) {
    final lane = widget.document.elementJson(id)?['lane'];
    if (lane == null) return [id];
    final ids = <String>[];
    void walk(Object? raw) {
      if (raw is List) {
        raw.forEach(walk);
      }
      if (raw is Map) {
        if (raw['type'] == 'Clip' && raw['lane'] == lane && raw['id'] is String) {
          ids.add(raw['id'] as String);
        }
        for (final entry in raw.entries) {
          if (entry.key != 'editor') walk(entry.value);
        }
      }
    }

    walk(widget.document.toJson());
    return ids;
  }

  Future<void> _import(String id) async {
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final cube = await widget.onImportLut!();
      if (!mounted || cube == null) return;
      CubeLut.parse(cube);
      widget.onCommand(
        AddEffectCommand(id: id, effect: {'kind': 'lut', 'cube': cube, 'intensity': 1.0}),
      );
      setState(() => _message = 'LUT imported and embedded in the document.');
    } on Object catch (error) {
      if (mounted) setState(() => _message = 'LUT import failed: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref
        .watch(selectionProvider)
        .where((id) => widget.document.elementJson(id) != null)
        .toList();
    return ColoredBox(
      color: context.colors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const OiLabel.body('Looks'),
            MathNumberInput(
              key: const ValueKey('look-intensity'),
              label: 'Look intensity',
              value: _intensity,
              min: 0,
              max: 1,
              step: 0.05,
              decimals: 2,
              onChanged: (value) => setState(() => _intensity = value),
            ),
            _ColourLooks(
              onSelected: selected.isEmpty ? null : (look) => _applyLook(look, selected),
            ),
            if (selected.isEmpty)
              OiLabel.body('Select an element to grade it.', color: context.colors.textSubtle),
            if (selected.isNotEmpty) ...[
              _GradeTransferActions(
                onCopy: () => _copy(selected),
                onPaste: () => _paste(selected),
                onPasteToLane: () => _paste(_laneIds(selected.first)),
              ),
              if (selected.length == 1) ...[
                _ColourCorrectionActions(
                  onCorrection: () => widget.onCommand(
                    AddEffectCommand(id: selected.single, effect: const {'kind': 'grade'}),
                  ),
                  onCurves: () => widget.onCommand(
                    AddEffectCommand(id: selected.single, effect: const {'kind': 'curves'}),
                  ),
                  importing: _importing,
                  onImport: _importing || widget.onImportLut == null
                      ? null
                      : () => _import(selected.single),
                ),
                EffectsSection(
                  document: widget.document,
                  elementId: selected.single,
                  onCommand: widget.onCommand,
                  playheadProgress: widget.playheadProgress,
                  kinds: colourEffectKinds,
                ),
              ] else
                OiLabel.small(
                  '${selected.length} elements selected. Looks and Paste grade apply to all.',
                ),
            ],
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Semantics(liveRegion: true, child: OiLabel.small(_message!)),
              ),
            if (widget.scopes case final ColourScopesController scopes)
              ColourScopes(controller: scopes),
          ],
        ),
      ),
    );
  }
}
