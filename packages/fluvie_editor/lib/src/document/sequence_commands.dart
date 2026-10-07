part of 'editor_command.dart';

/// Several commands as one intention.
///
/// A verb that has to touch more than one element — a ripple closing a gap, a
/// roll moving a cut — is still one thing the author did, so it is one undo
/// step by construction rather than by its parts agreeing on a merge key.
///
/// The parts apply in order and each sees what the one before it wrote, which
/// is what lets a sequence trim something and then move what follows it.
final class SequenceCommand extends EditorCommand {
  /// Applies [commands] in order, under [label]. A non-null [mergeGroup]
  /// coalesces a drag's stream of sequences into one undo step.
  const SequenceCommand(this.commands, {required this.label, this.mergeGroup});

  /// The parts, in the order they apply.
  final List<EditorCommand> commands;

  @override
  final String label;

  /// The coalescing group, or null for a standalone step.
  final String? mergeGroup;

  @override
  EditorDocument apply(EditorDocument document) =>
      commands.fold(document, (next, command) => command.apply(next));

  @override
  Set<String> get affectedIds => {for (final command in commands) ...command.affectedIds};

  @override
  String? get mergeKey => mergeGroup == null ? null : 'sequence:$mergeGroup';
}
