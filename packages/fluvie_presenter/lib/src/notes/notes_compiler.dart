import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluvie/fluvie.dart' show Video, walkWidgetTree;
import 'package:fluvie_presenter/src/notes/slide_notes.dart';
import 'package:fluvie_presenter/src/notes/speaker_notes.dart';
import 'package:fluvie_presenter/src/stepping/slide_plan.dart';
import 'package:fluvie_presenter/src/stepping/stop.dart';

/// Resolves [video]'s speaker notes per `(slide, step)`, aligned with the
/// compiled [plans]: `result[slide][step]`.
///
/// Pure and deterministic — the same structural walk the step compiler uses.
/// Notes outside any `Stop` are the scene default every step inherits; notes
/// inside a `Stop` apply while that stop's step is active, replacing the
/// text (when they have one) and appending their highlights. Several notes
/// in one scope merge in document order, texts joined by a blank line.
List<List<SlideNotes>> compileNotes(Video video, List<SlidePlan> plans) => List.unmodifiable([
  for (final plan in plans) _compileScene(video, plan),
]);

List<SlideNotes> _compileScene(Video video, SlidePlan plan) {
  final scene = video.scenes[plan.sceneIndex];
  final sceneNotes = <SpeakerNotes>[];
  for (final child in scene.children) {
    walkWidgetTree(child, (widget) {
      if (widget is SpeakerNotes) sceneNotes.add(widget);
    });
  }
  // A note under a stop belongs to that stop's step, not the scene default
  // (and not an enclosing stop: the nearest one wins).
  final byStop = <Stop, List<SpeakerNotes>>{};
  for (final step in plan.steps) {
    for (final stop in step.stops) {
      byStop[stop] = _ownNotes(stop);
      byStop[stop]!.forEach(sceneNotes.remove);
    }
  }
  final sceneDefault = _merge(sceneNotes);
  return List.unmodifiable([
    for (final step in plan.steps)
      _overlay(sceneDefault, _merge([for (final stop in step.stops) ...?byStop[stop]])),
  ]);
}

/// The notes directly under [stop], excluding what a nested stop claims for
/// its own later step.
List<SpeakerNotes> _ownNotes(Stop stop) {
  final all = <SpeakerNotes>[];
  walkWidgetTree(stop, (widget) {
    if (widget is SpeakerNotes) all.add(widget);
  });
  walkWidgetTree(stop, (widget) {
    if (widget is Stop && !identical(widget, stop)) {
      walkWidgetTree(widget, (nested) {
        if (nested is SpeakerNotes) all.remove(nested);
      });
    }
  });
  return all;
}

/// Merges one scope's notes in document order: texts joined by a blank
/// line, highlights concatenated.
SlideNotes _merge(List<SpeakerNotes> notes) {
  final texts = [
    for (final note in notes)
      if (note.text != null) note.text!,
  ];
  return SlideNotes(
    text: texts.isEmpty ? null : texts.join('\n\n'),
    highlights: List.unmodifiable([for (final note in notes) ...note.highlights]),
  );
}

/// Applies the step [override] onto the [sceneDefault]: text replaces when
/// present, highlights append.
SlideNotes _overlay(SlideNotes sceneDefault, SlideNotes override) => SlideNotes(
  text: override.text ?? sceneDefault.text,
  highlights: List.unmodifiable([...sceneDefault.highlights, ...override.highlights]),
);

/// The compiled notes for the mounted deck, `[slide][step]`; the presenter
/// shell overrides it next to `slidePlansProvider`.
final slideNotesProvider = Provider<List<List<SlideNotes>>>(
  (ref) => throw UnimplementedError(
    'slideNotesProvider must be overridden with the compiled notes '
    '(compileNotes(video, plans)) before the notes panel can read them.',
  ),
);
