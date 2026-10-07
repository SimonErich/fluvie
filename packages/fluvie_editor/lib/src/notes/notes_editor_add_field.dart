part of 'notes_editor.dart';

/// The always-empty field at the highlight list's foot: committing text
/// appends a bullet and the field clears for the next one (a remount, so
/// the document never carries a blank bullet while one is being typed).
final class _HighlightAddField extends StatefulWidget {
  const _HighlightAddField({required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  State<_HighlightAddField> createState() => _HighlightAddFieldState();
}

final class _HighlightAddFieldState extends State<_HighlightAddField> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) => InspectorTextField(
    key: ValueKey(_generation),
    value: '',
    placeholder: 'Add a highlight',
    onChanged: (text) {
      widget.onAdd(text);
      setState(() => _generation++);
    },
  );
}
