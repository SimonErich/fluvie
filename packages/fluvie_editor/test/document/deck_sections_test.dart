import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

/// Six slides, each carrying one recognizable element.
Map<String, Object?> _deck({int scenes = 6}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    for (var s = 0; s < scenes; s++)
      {
        'duration': '60f',
        'children': [
          {'id': 'el-$s', 'type': 'Text', 'text': 'slide $s'},
        ],
      },
  ],
};

/// The deck with a named section marker on [at].
EditorDocument _marked(EditorDocument document, int at, String name, {bool collapsed = false}) =>
    document.setSceneMeta(at, {
      'section': {'name': name, if (collapsed) 'collapsed': true},
    });

/// The slide order as element ids (slides are recognizable by content).
List<String> _order(EditorDocument document) => [
  for (var s = 0; s < document.sceneCount; s++) document.elementIdsInScene(s).single,
];

void main() {
  group('deckSections', () {
    test('a deck without markers is one unnamed section', () {
      final sections = deckSections(EditorDocument.fromJson(_deck()));
      expect(sections, hasLength(1));
      expect(sections.single.name, isNull);
      expect(sections.single.collapsed, isFalse);
      expect(sections.single.start, 0);
      expect(sections.single.count, 6);
      expect(sections.single.end, 6);
    });

    test('markers split the deck; slides before the first marker stay unsectioned', () {
      var document = EditorDocument.fromJson(_deck());
      document = _marked(document, 2, 'Middle');
      document = _marked(document, 4, 'Closing', collapsed: true);
      final sections = deckSections(document);
      expect(sections, hasLength(3));
      expect(sections[0].name, isNull);
      expect((sections[0].start, sections[0].count), (0, 2));
      expect(sections[1].name, 'Middle');
      expect(sections[1].collapsed, isFalse);
      expect((sections[1].start, sections[1].count), (2, 2));
      expect(sections[2].name, 'Closing');
      expect(sections[2].collapsed, isTrue);
      expect((sections[2].start, sections[2].count), (4, 2));
    });

    test('a marker on slide zero leaves no unnamed run', () {
      final document = _marked(EditorDocument.fromJson(_deck()), 0, 'All');
      final sections = deckSections(document);
      expect(sections, hasLength(1));
      expect(sections.single.name, 'All');
      expect((sections.single.start, sections.single.count), (0, 6));
    });

    test('a marker without a name falls back to "Section"', () {
      final document = EditorDocument.fromJson(
        _deck(),
      ).setSceneMeta(1, {'section': <String, Object?>{}});
      expect(deckSections(document)[1].name, 'Section');
    });

    test('section markers never move the render digest', () {
      final document = EditorDocument.fromJson(_deck());
      final sectioned = _marked(document, 2, 'Middle');
      expect(sectioned.renderDigest, document.renderDigest);
      expect(sectioned.documentDigest, isNot(document.documentDigest));
    });

    test('a null value removes the marker through setSceneMeta', () {
      var document = _marked(EditorDocument.fromJson(_deck()), 2, 'Middle');
      document = document.setSceneMeta(2, {'section': null});
      expect(document.sceneMeta(2), isEmpty);
      expect(deckSections(document), hasLength(1));
    });
  });

  group('markers follow their slide', () {
    /// Unsectioned 0-1, "Middle" 2-3, "Closing" 4-5.
    EditorDocument base() {
      var document = EditorDocument.fromJson(_deck());
      document = _marked(document, 2, 'Middle');
      return _marked(document, 4, 'Closing');
    }

    test('adding a slide inside a section grows it', () {
      final document = base().addScene({'duration': '10f'}, at: 3);
      final sections = deckSections(document);
      expect(sections[1].name, 'Middle');
      expect((sections[1].start, sections[1].count), (2, 3));
      expect((sections[2].start, sections[2].count), (5, 2));
    });

    test('adding a slide before a section shifts it whole', () {
      final document = base().addScene({'duration': '10f'}, at: 0);
      final sections = deckSections(document);
      expect((sections[0].start, sections[0].count), (0, 3));
      expect((sections[1].start, sections[1].count), (3, 2));
      expect((sections[2].start, sections[2].count), (5, 2));
    });

    test('adding a slide after every section changes nothing before it', () {
      final document = base().addScene({'duration': '10f'});
      final sections = deckSections(document);
      expect((sections[1].start, sections[1].count), (2, 2));
      expect((sections[2].start, sections[2].count), (4, 3));
    });

    test('removing a slide inside a section shrinks it', () {
      final document = base().removeScene(3);
      final sections = deckSections(document);
      expect((sections[1].start, sections[1].count), (2, 1));
      expect(sections[2].name, 'Closing');
      expect((sections[2].start, sections[2].count), (3, 2));
    });

    test('removing the marked slide merges the rest into the previous section', () {
      final document = base().removeScene(2);
      final sections = deckSections(document);
      expect(sections, hasLength(2));
      expect(sections[0].name, isNull);
      expect((sections[0].start, sections[0].count), (0, 3));
      expect(sections[1].name, 'Closing');
      expect((sections[1].start, sections[1].count), (3, 2));
    });

    test('reordering an unmarked slide across sections moves membership by position', () {
      // Slide 0 (unsectioned) lands between Middle's slides: it joins Middle.
      final document = base().reorderScene(0, 2);
      final sections = deckSections(document);
      expect((sections[0].start, sections[0].count), (0, 1));
      expect(sections[1].name, 'Middle');
      expect((sections[1].start, sections[1].count), (1, 3));
      expect(_order(document), ['el-1', 'el-2', 'el-0', 'el-3', 'el-4', 'el-5']);
    });

    test('reordering the marked slide carries its marker', () {
      // Middle's marked slide moves to the end: the marker goes with it, so
      // "Middle" restarts there and its orphaned second slide falls back
      // into the unnamed run.
      final document = base().reorderScene(2, 5);
      expect(_order(document), ['el-0', 'el-1', 'el-3', 'el-4', 'el-5', 'el-2']);
      final sections = deckSections(document);
      expect(sections.map((s) => s.name), [null, 'Closing', 'Middle']);
      expect((sections[0].start, sections[0].count), (0, 3));
      expect((sections[1].start, sections[1].count), (3, 2));
      expect((sections[2].start, sections[2].count), (5, 1));
    });
  });

  group('reorderSceneRange', () {
    test('moves a block up, slides and metadata together', () {
      var document = EditorDocument.fromJson(_deck());
      document = _marked(document, 3, 'Late');
      final moved = document.reorderSceneRange(start: 3, count: 2, to: 1);
      expect(_order(moved), ['el-0', 'el-3', 'el-4', 'el-1', 'el-2', 'el-5']);
      expect(moved.sceneMeta(1)['section'], {'name': 'Late'});
      expect(moved.sceneMeta(3), isEmpty);
    });

    test('moves a block down keeping its internal order', () {
      final document = EditorDocument.fromJson(_deck());
      final moved = document.reorderSceneRange(start: 0, count: 2, to: 3);
      expect(_order(moved), ['el-2', 'el-3', 'el-4', 'el-0', 'el-1', 'el-5']);
    });

    test('moving to the same start is identity', () {
      final document = EditorDocument.fromJson(_deck());
      expect(_order(document.reorderSceneRange(start: 2, count: 2, to: 2)), _order(document));
    });

    test('two sections swap as units and their markers follow', () {
      var document = EditorDocument.fromJson(_deck());
      document = _marked(document, 2, 'Middle');
      document = _marked(document, 4, 'Closing');
      // Move "Closing" (4-5) above "Middle" (2-3).
      final swapped = document.reorderSceneRange(start: 4, count: 2, to: 2);
      expect(_order(swapped), ['el-0', 'el-1', 'el-4', 'el-5', 'el-2', 'el-3']);
      final sections = deckSections(swapped);
      expect(sections.map((s) => s.name), [null, 'Closing', 'Middle']);
      expect((sections[1].start, sections[1].count), (2, 2));
      expect((sections[2].start, sections[2].count), (4, 2));
    });

    test('rejects a range or target outside the deck', () {
      final document = EditorDocument.fromJson(_deck());
      expect(() => document.reorderSceneRange(start: -1, count: 2, to: 0), throwsRangeError);
      expect(() => document.reorderSceneRange(start: 0, count: 0, to: 0), throwsRangeError);
      expect(() => document.reorderSceneRange(start: 5, count: 2, to: 0), throwsRangeError);
      expect(() => document.reorderSceneRange(start: 0, count: 2, to: 5), throwsRangeError);
    });
  });

  group('ReorderSceneRangeCommand', () {
    test('moves the run through history and undoes in one step', () {
      var document = EditorDocument.fromJson(_deck());
      document = _marked(document, 4, 'Closing');
      final history = DocumentHistory(document)
        ..dispatch(const ReorderSceneRangeCommand(start: 4, count: 2, to: 0));
      expect(_order(history.document), ['el-4', 'el-5', 'el-0', 'el-1', 'el-2', 'el-3']);
      expect(history.document.sceneMeta(0)['section'], {'name': 'Closing'});
      expect(history.undoLabel, 'Move section');
      history.undo();
      expect(_order(history.document), ['el-0', 'el-1', 'el-2', 'el-3', 'el-4', 'el-5']);
      expect(history.document.sceneMeta(4)['section'], {'name': 'Closing'});
    });
  });
}
