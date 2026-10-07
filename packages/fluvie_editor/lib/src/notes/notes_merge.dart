import 'package:fluvie_presenter/fluvie_presenter.dart' show SlideNotes;

/// What the speaker sees for one `(slide, step)` position, merged locally
/// from the spec's raw notes JSON by the documented rule: a step's text
/// replaces the [scene] text while that step is active, and its highlights
/// append to the scene's.
///
/// This mirrors the presenter's `compileNotes` result for the same position
/// without building a deck — the notes editor's merge preview reads it per
/// keystroke. The parity tests pin the mirror to the real compiler. Both
/// arguments are raw notes objects (`text` and `highlights`); malformed
/// shapes read as absent, so the editor stays up while validation reports.
SlideNotes mergedSlideNotes({
  required Map<String, Object?>? scene,
  required Map<String, Object?>? step,
}) {
  String? text(Map<String, Object?>? notes) {
    final value = notes?['text'];
    return value is String ? value : null;
  }

  List<String> highlights(Map<String, Object?>? notes) {
    final value = notes?['highlights'];
    return value is List ? [...value.whereType<String>()] : const [];
  }

  return SlideNotes(
    text: text(step) ?? text(scene),
    highlights: List.unmodifiable([...highlights(scene), ...highlights(step)]),
  );
}
