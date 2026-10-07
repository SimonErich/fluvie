import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart'
    show SlideNotes, compileNotes, compileSlidePlans, deckFromSpec;

/// A two-step slide plus a step-less slide — the shapes the editor authors.
Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': <Object?>[
    <String, Object?>{
      'duration': '120f',
      'children': [
        {'id': 'el-title', 'type': 'Text', 'text': 'title'},
        {'id': 'el-b1', 'type': 'Text', 'text': 'first'},
        {'id': 'el-b2', 'type': 'Text', 'text': 'second'},
      ],
      'steps': [
        {
          'elements': ['el-b1'],
        },
        {
          'elements': ['el-b2'],
        },
      ],
    },
    <String, Object?>{
      'duration': '60f',
      'children': [
        {'id': 'el-solo', 'type': 'Text', 'text': 'solo'},
      ],
    },
  ],
};

/// What the editor's merge preview shows for each scope of [slide]: the
/// scene scope first, then one entry per listed step — the local mirror the
/// notes editor renders.
List<SlideNotes> _editorView(EditorDocument document, int slide) {
  final scene = document.sceneJson(slide);
  final sceneNotes = scene['notes'] as Map<String, Object?>?;
  final steps = [...(scene['steps'] as List? ?? const []).whereType<Map<String, Object?>>()];
  return [
    mergedSlideNotes(scene: sceneNotes, step: null),
    for (final step in steps)
      mergedSlideNotes(scene: sceneNotes, step: step['notes'] as Map<String, Object?>?),
  ];
}

void main() {
  test('what the editor shows is what the speaker window compiles, step for step', () {
    final history = DocumentHistory(EditorDocument.fromJson(_deck()))
      ..dispatch(
        const SetSceneNotesCommand(
          index: 0,
          notes: {
            'text': 'Open with the outage story.',
            'highlights': ['3am page', 'one line fix'],
          },
        ),
      )
      ..dispatch(
        const SetStepNotesCommand(
          index: 0,
          step: 1,
          notes: {
            'text': 'Land the punchline.',
            'highlights': ['pause here'],
          },
        ),
      )
      ..dispatch(const SetSceneNotesCommand(index: 1, notes: {'text': 'Wrap up.'}));

    final document = history.document;
    final video = deckFromSpec(document.spec);
    final compiled = compileNotes(video, compileSlidePlans(video));

    expect(compiled, hasLength(2));
    for (var slide = 0; slide < compiled.length; slide++) {
      final editor = _editorView(document, slide);
      expect(compiled[slide], hasLength(editor.length), reason: 'slide $slide step count');
      for (var step = 0; step < editor.length; step++) {
        expect(compiled[slide][step], editor[step], reason: 'slide $slide, step $step');
      }
    }

    // The merge rule, spelled out: step 2's text replaced, highlights
    // appended after the scene's.
    expect(
      compiled[0][2],
      const SlideNotes(
        text: 'Land the punchline.',
        highlights: ['3am page', 'one line fix', 'pause here'],
      ),
    );
  });

  test('a note-free deck compiles to empty views on both sides', () {
    final document = EditorDocument.fromJson(_deck());
    final video = deckFromSpec(document.spec);
    final compiled = compileNotes(video, compileSlidePlans(video));
    for (var slide = 0; slide < compiled.length; slide++) {
      final editor = _editorView(document, slide);
      for (var step = 0; step < editor.length; step++) {
        expect(compiled[slide][step], editor[step]);
        expect(editor[step].isEmpty, isTrue);
      }
    }
  });
}
