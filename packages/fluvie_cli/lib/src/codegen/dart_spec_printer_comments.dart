part of 'dart_spec_printer.dart';

/// The one-line heads-up printed when [spec] declares lanes, or null when it
/// declares none.
///
/// Lanes are where a timeline draws material, and plain fluvie code has no
/// timeline: the printed Dart renders the same pixels without them. A muted
/// lane is the exception, and its tracks are already gone from the print, so
/// the note says which ones.
String? _lanesComment(Map<String, Object?> spec) {
  final lanes = spec['lanes'];
  if (lanes is! List || lanes.isEmpty) return null;
  final muted = _mutedLaneIds(spec);
  final silenced = muted.isEmpty
      ? ''
      : ' The ${muted.length} muted lane${muted.length == 1 ? '' : 's'} '
            '(${(muted.toList()..sort()).join(', ')}) had their audio left out, '
            'exactly as a render leaves it out.';
  return '// lanes: this deck declares ${lanes.length} timeline '
      'lane${lanes.length == 1 ? '' : 's'}; they say where an editor draws '
      'material and this printed Dart renders the same pixels without them.'
      '$silenced';
}

/// The one-line heads-up printed when [spec] carries build steps or speaker
/// notes, or null when it carries neither. Plain fluvie code cannot express
/// them, so the printed Dart plays straight through; `deckFromSpec` in
/// `package:fluvie_presenter` is what preserves them from the spec.
String? _stepsNotesComment(Map<String, Object?> spec) {
  final scenes = spec['scenes'];
  if (scenes is! List) return null;
  var steps = 0;
  var hasNotes = false;
  for (final scene in scenes) {
    if (scene is! Map<String, Object?>) continue;
    final sceneSteps = scene['steps'];
    if (sceneSteps is List) {
      steps += sceneSteps.length;
      hasNotes |= sceneSteps.any((step) => step is Map<String, Object?> && step['notes'] != null);
    }
    hasNotes |= scene['notes'] != null;
  }
  if (steps == 0 && !hasNotes) return null;
  final declared = [
    if (steps > 0) '$steps build step${steps == 1 ? '' : 's'}',
    if (hasNotes) 'speaker notes',
  ].join(' and ');
  return '// steps/notes: this deck declares $declared; this printed Dart is plain '
      'fluvie and cannot express them, but deckFromSpec (package:fluvie_presenter) '
      'preserves them from the spec.';
}
