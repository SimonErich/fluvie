part of 'editor_command.dart';

/// Changes the source marks or folder of one asset as one undoable edit.
final class UpdateMediaEntryCommand extends EditorCommand {
  /// Replaces the existing entry with [entry].
  const UpdateMediaEntryCommand({required this.entry});

  /// The asset's updated metadata.
  final MediaStoreEntry entry;

  @override
  EditorDocument apply(EditorDocument document) => document.replaceMediaEntry(entry);

  @override
  String get label => 'Update ${entry.name}';

  @override
  Set<String> get affectedIds => const {};
}

/// Adds one imported media entry to the document's store (`editor.media`).
final class AddMediaEntryCommand extends EditorCommand {
  /// Records [entry] in the store.
  const AddMediaEntryCommand({required this.entry});

  /// The entry being recorded (its id minted through
  /// `EditorDocument.nextMediaId`).
  final MediaStoreEntry entry;

  @override
  EditorDocument apply(EditorDocument document) => document.addMediaEntry(entry);

  @override
  String get label => 'Import ${entry.name}';

  @override
  Set<String> get affectedIds => const {};
}

/// Removes one media entry from the document's store.
final class RemoveMediaEntryCommand extends EditorCommand {
  /// Removes the entry with [id].
  const RemoveMediaEntryCommand({required this.id});

  /// The store id being removed.
  final String id;

  @override
  EditorDocument apply(EditorDocument document) => document.removeMediaEntry(id);

  @override
  String get label => 'Remove $id';

  @override
  Set<String> get affectedIds => const {};
}

/// Writes the deck-level editor metadata channel (`editor.deck`) — warning
/// suppressions and friends.
final class SetDeckMetaCommand extends EditorCommand {
  /// Merges [meta] over the deck channel; a null value removes its key.
  const SetDeckMetaCommand({required this.meta});

  /// The keys to merge (null values remove).
  final Map<String, Object?> meta;

  @override
  EditorDocument apply(EditorDocument document) => document.setDeckMeta(meta);

  @override
  String get label => 'Set deck options';

  @override
  Set<String> get affectedIds => const {};
}
