part of 'notes_editor.dart';

/// The strip's fields: the prose area, the highlight bullets (add, edit in
/// place, reorder, remove), and the read-only merge preview that shows what
/// the speaker window will show for the selected scope.
extension _NotesEditorFields on _NotesEditorState {
  Widget _body(
    BuildContext context,
    Map<String, Object?> scene,
    List<Map<String, Object?>> steps,
    int scope,
  ) {
    final notes = _notesAt(scene, steps, scope);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (steps.isNotEmpty) ...[
            _scopeChips(context, steps.length, scope),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _textColumn(context, scope, notes)),
                const SizedBox(width: 16),
                SizedBox(width: 260, child: _highlightsColumn(context, scope, notes)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _preview(context, scene, steps, scope),
        ],
      ),
    );
  }

  Widget _textColumn(BuildContext context, int scope, Map<String, Object?>? notes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      OiLabel.small('What to say', color: context.colors.textSubtle),
      const SizedBox(height: 4),
      KeyedSubtree(
        key: const ValueKey('note-text'),
        child: InspectorTextField(
          value: _textOf(notes),
          maxLines: 4,
          placeholder: scope == 0
              ? 'Type what the speaker should say'
              : 'Replace the slide text for this step',
          onChanged: (next) => _dispatch(scope, current: notes, text: next),
        ),
      ),
    ],
  );

  Widget _highlightsColumn(BuildContext context, int scope, Map<String, Object?>? notes) {
    final bullets = _highlightsOf(notes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OiLabel.small('Highlights', color: context.colors.textSubtle),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < bullets.length; i++)
                _bulletRow(context, scope, notes, bullets, i),
              KeyedSubtree(
                key: const ValueKey('note-add-highlight'),
                child: _HighlightAddField(
                  onAdd: (text) => _dispatch(scope, current: notes, highlights: [...bullets, text]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bulletRow(
    BuildContext context,
    int scope,
    Map<String, Object?>? notes,
    List<String> bullets,
    int index,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: KeyedSubtree(
      key: ValueKey('note-highlight-$index'),
      child: Row(
        children: [
          Expanded(
            child: InspectorTextField(
              value: bullets[index],
              // An emptied bullet removes itself — no blank rows linger.
              onChanged: (next) => _dispatch(
                scope,
                current: notes,
                highlights: [
                  for (var j = 0; j < bullets.length; j++)
                    if (j != index) bullets[j] else if (next.isNotEmpty) next,
                ],
              ),
            ),
          ),
          _bulletButton(
            'Move the highlight up',
            OiIcons.arrowUp,
            index == 0 ? null : () => _moveBullet(scope, notes, bullets, index, index - 1),
          ),
          _bulletButton(
            'Move the highlight down',
            OiIcons.arrowDown,
            index == bullets.length - 1
                ? null
                : () => _moveBullet(scope, notes, bullets, index, index + 1),
          ),
          _bulletButton(
            'Remove the highlight',
            OiIcons.x,
            () => _dispatch(
              scope,
              current: notes,
              highlights: [...bullets]..removeAt(index),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bulletButton(String label, IconData icon, VoidCallback? onTap) => EditorTip(
    message: label,
    child: OiIconButton(
      icon: icon,
      semanticLabel: label,
      size: OiButtonSize.small,
      onTap: onTap,
    ),
  );

  void _moveBullet(
    int scope,
    Map<String, Object?>? notes,
    List<String> bullets,
    int from,
    int to,
  ) {
    final next = [...bullets];
    next.insert(to, next.removeAt(from));
    _dispatch(scope, current: notes, highlights: next);
  }

  /// The merge preview: the scene default overlaid with the selected
  /// step's override — locally mirrored `compileNotes`, so this line IS
  /// what the speaker window shows for this scope.
  Widget _preview(
    BuildContext context,
    Map<String, Object?> scene,
    List<Map<String, Object?>> steps,
    int scope,
  ) {
    final view = mergedSlideNotes(
      scene: _notesAt(scene, steps, 0),
      step: scope == 0 ? null : _notesAt(scene, steps, scope),
    );
    final content = [
      if (view.text case final String text) text,
      if (view.highlights.isNotEmpty) view.highlights.join(' · '),
    ].join(' — ');
    return OiLabel.small(
      'Speaker sees: ${content.isEmpty ? 'nothing yet' : content}',
      color: context.colors.textSubtle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
