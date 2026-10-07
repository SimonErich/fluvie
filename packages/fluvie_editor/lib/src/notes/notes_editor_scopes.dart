part of 'notes_editor.dart';

/// The strip's scope layer: which notes object is being edited — the slide
/// default, or one listed step's override — plus the chip row that switches
/// between them and the one dispatch every field edit funnels through.
extension _NotesEditorScopes on _NotesEditorState {
  /// The scene's listed steps, shape-tolerant (a malformed list reads as
  /// empty — validation reports it, the strip stays up).
  List<Map<String, Object?>> _stepsOf(Map<String, Object?> scene) => [
    ...(scene['steps'] as List? ?? const []).whereType<Map<String, Object?>>(),
  ];

  /// The raw notes object [scope] edits: the scene's, or listed step
  /// `scope - 1`'s override.
  Map<String, Object?>? _notesAt(
    Map<String, Object?> scene,
    List<Map<String, Object?>> steps,
    int scope,
  ) {
    final notes = scope == 0 ? scene['notes'] : steps[scope - 1]['notes'];
    return notes is Map<String, Object?> ? notes : null;
  }

  String _textOf(Map<String, Object?>? notes) {
    final value = notes?['text'];
    return value is String ? value : '';
  }

  List<String> _highlightsOf(Map<String, Object?>? notes) {
    final value = notes?['highlights'];
    return value is List ? [...value.whereType<String>()] : const [];
  }

  /// Writes [current] with [text] or [highlights] swapped in, onto the
  /// scope's command — the command canonicalizes, so a cleared field drops
  /// its key and clearing everything removes the notes object.
  void _dispatch(
    int scope, {
    required Map<String, Object?>? current,
    String? text,
    List<String>? highlights,
  }) {
    final notes = {
      'text': text ?? _textOf(current),
      'highlights': highlights ?? _highlightsOf(current),
    };
    widget.onCommand(
      scope == 0
          ? SetSceneNotesCommand(index: widget.slide, notes: notes)
          : SetStepNotesCommand(index: widget.slide, step: scope - 1, notes: notes),
    );
  }

  Widget _scopeChips(BuildContext context, int count, int scope) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _chip(context, 'Slide', 0, scope),
        for (var step = 1; step <= count; step++) ...[
          const SizedBox(width: 6),
          _chip(context, 'Step $step', step, scope),
        ],
      ],
    ),
  );

  Widget _chip(BuildContext context, String label, int value, int scope) {
    final colors = context.colors;
    final active = value == scope;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _refresh(() => _scope = value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? colors.surfaceSubtle : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? colors.border : colors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: OiLabel.small(label, color: active ? colors.text : colors.textSubtle),
        ),
      ),
    );
  }
}
