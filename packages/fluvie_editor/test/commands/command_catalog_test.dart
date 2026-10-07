import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

import 'fake_system_clipboard.dart';

Map<String, Object?> _deck() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-a',
          'type': 'Box',
          'color': '#E17055',
          'anchor': 'intro',
          'transform': {'x': 0.2, 'y': 0.4, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-b',
          'type': 'Box',
          'color': '#0984E3',
          'animate': [
            {
              'preset': 'fadeIn',
              'at': {'kind': 'whenEnds', 'anchor': 'intro'},
            },
          ],
          'transform': {'x': 0.6, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
        {
          'id': 'el-g',
          'type': 'Group',
          'transform': {'x': 0.5, 'y': 0.8, 'w': 0.4, 'h': 0.2},
          'children': [
            {
              'id': 'el-gc',
              'type': 'Box',
              'color': '#6C5CE7',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
            },
          ],
        },
      ],
    },
    {
      'duration': '60f',
      'children': [
        {
          'id': 'el-z',
          'type': 'Box',
          'color': '#2ECC8F',
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.2, 'h': 0.2},
        },
      ],
    },
    {'duration': '60f', 'children': <Object?>[]},
  ],
};

/// A live editing surface for one document: history-backed dispatch and
/// recorded side channels, rebuilt into a fresh scope on demand.
final class _Surface {
  _Surface({Map<String, Object?>? deck, EditorClipboard? clipboard})
    : history = DocumentHistory(EditorDocument.fromJson(deck ?? _deck())),
      clipboard = clipboard ?? EditorClipboard();

  final DocumentHistory history;
  final EditorClipboard clipboard;
  Set<String> selection = const {};
  String? enteredGroup;
  int shownSlide = -1;

  EditorDocument get document => history.document;

  CommandScope scope({int slide = 0}) {
    // The canvas's own frame mapping: entered groups edit in their box.
    final frame = enteredGroup == null ? null : groupFrameRect(document, enteredGroup!);
    return CommandScope(
      document: document,
      slide: slide,
      selection: selection,
      enteredGroup: enteredGroup,
      clipboard: clipboard,
      dispatch: history.dispatch,
      select: (ids) => selection = ids,
      exitGroup: () => enteredGroup = null,
      showSlide: (next) => shownSlide = next,
      rectOf: (id) => SceneGeometry.of(document, slide, enteredGroup: enteredGroup).rectOf(id),
      frameOrigin: frame?.topLeft ?? Offset.zero,
      frameSize: frame?.size,
    );
  }

  Future<void> run(String id, {int slide = 0}) =>
      editorCommandById(id).execute(scope(slide: slide));
}

double _x(EditorDocument document, String id) =>
    ((document.elementJson(id)!['transform']! as Map<String, Object?>)['x']! as num).toDouble();

double _w(EditorDocument document, String id) =>
    ((document.elementJson(id)!['transform']! as Map<String, Object?>)['w']! as num).toDouble();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The clipboard rides the platform channel; an unmocked channel never
  // answers in tests, so every case runs over the fake system clipboard.
  final fake = FakeSystemClipboard();
  setUp(fake.install);
  tearDown(() {
    fake
      ..text = null
      ..uninstall();
  });

  group('copy and cut', () {
    test('copy writes the selection to the clipboard in z-order', () async {
      final surface = _Surface()..selection = {'el-g', 'el-a'};
      await surface.run('edit.copy');
      final envelope = await surface.clipboard.read();
      expect(envelope, isNotNull);
      expect(envelope!.elements.map((e) => e['id']), ['el-a', 'el-g']);
      expect(envelope.sourceIds, {'el-a', 'el-g', 'el-gc'});
      // Copy alone never touches the document.
      expect(surface.history.canUndo, isFalse);
    });

    test('cut copies, removes, and clears the selection in one step', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('edit.cut');
      expect(surface.document.elementIdsInScene(0), ['el-b', 'el-g']);
      expect(surface.selection, isEmpty);
      expect((await surface.clipboard.read())!.elements.single['id'], 'el-a');
      surface.history.undo();
      expect(surface.document.elementIdsInScene(0), ['el-a', 'el-b', 'el-g']);
    });
  });

  group('paste', () {
    test('same-slide paste re-mints every id and nudges the copy', () async {
      final surface = _Surface()..selection = {'el-g'};
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      final ids = surface.document.elementIdsInScene(0);
      expect(ids, hasLength(4));
      final pastedGroup = ids.last;
      expect(pastedGroup, isNot('el-g'));
      final child = surface.document.childIdsOfGroup(pastedGroup).single;
      expect(child, isNot('el-gc'));
      // The Figma nudge: 10 canvas px right and down.
      expect(_x(surface.document, pastedGroup), closeTo(0.5 + 10 / 320, 1e-9));
      expect(surface.selection, {pastedGroup});
    });

    test('pasting twice keeps every id unique', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      await surface.run('edit.paste');
      final all = <String>[];
      for (final id in surface.document.elementIdsInScene(0)) {
        all
          ..add(id)
          ..addAll(surface.document.childIdsOfGroup(id));
      }
      expect(all.toSet(), hasLength(all.length));
      expect(surface.document.elementIdsInScene(0), hasLength(7));
    });

    test('cross-slide paste keeps the copied position', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('edit.copy');
      await surface.run('edit.paste', slide: 1);
      final pasted = surface.document.elementIdsInScene(1).last;
      expect(_x(surface.document, pasted), closeTo(0.2, 1e-9));
    });

    test('a colliding anchor re-mints consistently; escaping references hold', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      final pasted = surface.document.elementIdsInScene(0).skip(3).toList();
      final pastedA = surface.document.elementJson(pasted[0])!;
      final pastedB = surface.document.elementJson(pasted[1])!;
      expect(pastedA['anchor'], 'intro-2');
      final animate = pastedB['animate']! as List<Object?>;
      final at = (animate.single! as Map<String, Object?>)['at']! as Map<String, Object?>;
      expect(at['anchor'], 'intro-2');
      // The original keeps its anchor and its own reference.
      expect(surface.document.elementJson('el-a')!['anchor'], 'intro');
    });

    test('a lone trigger reference escaping the copied set is preserved', () async {
      final surface = _Surface()..selection = {'el-b'};
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      final pasted = surface.document.elementIdsInScene(0).last;
      final animate = surface.document.elementJson(pasted)!['animate']! as List<Object?>;
      final at = (animate.single! as Map<String, Object?>)['at']! as Map<String, Object?>;
      expect(at['anchor'], 'intro');
    });

    test('cross-document paste travels the shared clipboard, ids fresh', () async {
      final clipboard = EditorClipboard();
      final source = _Surface(clipboard: clipboard)..selection = {'el-a'};
      await source.run('edit.copy');
      final target = _Surface(
        clipboard: clipboard,
        deck: {
          'fluvieSpec': 1,
          'size': {'width': 320, 'height': 180},
          'fps': 30,
          'scenes': [
            {
              'duration': '60f',
              'children': [
                {'id': 'el-1', 'type': 'Box', 'color': '#FFFFFF'},
              ],
            },
          ],
        },
      );
      await target.run('edit.paste');
      final ids = target.document.elementIdsInScene(0);
      expect(ids, hasLength(2));
      expect(ids.last, isNot('el-a'));
      // No anchor collision in the target: the anchor travels verbatim, and
      // the position is kept (cross-document is never the same slide).
      expect(target.document.elementJson(ids.last)!['anchor'], 'intro');
      expect(_x(target.document, ids.last), closeTo(0.2, 1e-9));
      expect(target.selection, {ids.last});
    });

    test('an empty clipboard pastes nothing', () async {
      final surface = _Surface();
      await surface.run('edit.paste');
      expect(surface.history.canUndo, isFalse);
    });
  });

  group('paste into an entered group', () {
    test('the copies land inside the group with re-minted ids, nudged in frame pixels', () async {
      final surface = _Surface()
        ..selection = {'el-gc'}
        ..enteredGroup = 'el-g';
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      // The group stays entered and gains the copy as its own child.
      expect(surface.enteredGroup, 'el-g');
      expect(surface.document.elementIdsInScene(0), hasLength(3));
      final children = surface.document.childIdsOfGroup('el-g');
      expect(children, hasLength(2));
      final pasted = children.last;
      expect(pasted, isNot('el-gc'));
      // Fractions travel frame-relative: the same-slide nudge is ten pixels
      // of the group's own box (0.4 * 320 wide).
      expect(_x(surface.document, pasted), closeTo(0.5 + 10 / 128, 1e-9));
      expect(surface.selection, {pasted});
      expect(surface.history.undoLabel, contains('Paste'));
      surface.history.undo();
      expect(surface.document.childIdsOfGroup('el-g'), ['el-gc']);
    });

    test('duplicate lands beside the original inside the group', () async {
      final surface = _Surface()
        ..selection = {'el-gc'}
        ..enteredGroup = 'el-g';
      await surface.run('edit.duplicate');
      final children = surface.document.childIdsOfGroup('el-g');
      expect(children, hasLength(2));
      expect(_x(surface.document, children.last), closeTo(0.5 + 10 / 128, 1e-9));
      expect(surface.enteredGroup, 'el-g');
    });

    test('a block group re-balances the pasted newcomer into a slot', () async {
      final surface = _Surface()
        ..selection = {'el-gc'}
        ..enteredGroup = 'el-g';
      surface.history.dispatch(
        SetBlockParamsCommand(groupId: 'el-g', block: BlockSpec.defaults(BlockKind.row)),
      );
      await surface.run('edit.copy');
      await surface.run('edit.paste');
      final children = surface.document.childIdsOfGroup('el-g');
      expect(children, hasLength(2));
      // An equal-size row shares the width: both children hold equal slots.
      final widths = [for (final id in children) _w(surface.document, id)];
      expect(widths.first, closeTo(widths.last, 1e-9));
      expect(_x(surface.document, children.first), lessThan(_x(surface.document, children.last)));
    });

    test('a pasted group lands at the scene top level, never nested', () async {
      // Copy a top-level group, then enter another group and paste: the copy
      // is itself a Group, so it must land beside the entered group at the
      // scene's top level. Groups never nest by an editor gesture — move and
      // drag forbid it too, and paste holds the same one concept.
      final surface = _Surface()..selection = {'el-g'};
      await surface.run('edit.copy');
      surface.enteredGroup = 'el-g';
      await surface.run('edit.paste');
      final topLevel = surface.document.elementIdsInScene(0);
      expect(topLevel, hasLength(4));
      final pasted = topLevel.last;
      expect(pasted, isNot('el-g'));
      expect(surface.document.parentGroupOf(pasted), isNull);
      // The entered group gained no child.
      expect(surface.document.childIdsOfGroup('el-g'), ['el-gc']);
      // Still one undo step.
      expect(surface.history.undoLabel, contains('Paste'));
      surface.history.undo();
      expect(surface.document.elementIdsInScene(0), ['el-a', 'el-b', 'el-g']);
    });
  });

  group('duplicate and delete', () {
    test('duplicate nudges fresh copies and never touches the clipboard', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('edit.duplicate');
      final ids = surface.document.elementIdsInScene(0);
      expect(ids, hasLength(4));
      expect(_x(surface.document, ids.last), closeTo(0.2 + 10 / 320, 1e-9));
      expect(surface.selection, {ids.last});
      expect(await surface.clipboard.read(), isNull);
      expect(surface.history.undoLabel, contains('Duplicate'));
    });

    test('delete removes the whole selection in one step', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('edit.delete');
      expect(surface.document.elementIdsInScene(0), ['el-g']);
      expect(surface.selection, isEmpty);
      surface.history.undo();
      expect(surface.document.elementIdsInScene(0), ['el-a', 'el-b', 'el-g']);
    });

    test('select all takes the scope, skipping locked and hidden', () async {
      final surface = _Surface();
      surface.history.dispatch(const SetElementsMetaCommand(ids: ['el-a'], meta: {'locked': true}));
      surface.history.dispatch(const SetElementsVisibleCommand(ids: ['el-b'], visible: false));
      await surface.run('edit.selectAll');
      expect(surface.selection, {'el-g'});
    });

    test('select all inside an entered group selects its children', () async {
      final surface = _Surface()..enteredGroup = 'el-g';
      await surface.run('edit.selectAll');
      expect(surface.selection, {'el-gc'});
    });
  });

  group('arrange and object commands', () {
    test('bring forward moves the selection through the z-order', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('order.forward');
      expect(surface.document.elementIdsInScene(0), ['el-b', 'el-a', 'el-g']);
    });

    test('group wraps the selection at its bounding box and selects it', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('arrange.group');
      final groupId = surface.selection.single;
      expect(surface.document.childIdsOfGroup(groupId), ['el-a', 'el-b']);
    });

    test('ungroup dissolves and selects the children', () async {
      final surface = _Surface()..selection = {'el-g'};
      await surface.run('arrange.ungroup');
      expect(surface.selection, {'el-gc'});
      expect(surface.document.elementIdsInScene(0), ['el-a', 'el-b', 'el-gc']);
    });

    test('ungrouping the entered group exits it first', () async {
      final surface = _Surface()
        ..selection = {'el-g'}
        ..enteredGroup = 'el-g';
      await surface.run('arrange.ungroup');
      expect(surface.enteredGroup, isNull);
    });

    test('lock toggles the whole selection; a locked selection unlocks', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('object.lock');
      expect(surface.document.elementMeta('el-a')['locked'], isTrue);
      expect(surface.document.elementMeta('el-b')['locked'], isTrue);
      await surface.run('object.lock');
      expect(surface.document.elementMeta('el-a')['locked'], isFalse);
    });

    test('hide toggles the spec visible flag', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('object.hide');
      expect(surface.document.elementJson('el-a')!['visible'], isFalse);
      await surface.run('object.hide');
      expect(surface.document.elementJson('el-a')!['visible'], isNot(isFalse));
    });

    test('align left brings the selection to its shared left edge', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b'};
      await surface.run('align.left');
      final left = SceneGeometry.of(surface.document, 0);
      expect(left.rectOf('el-a')!.left, closeTo(left.rectOf('el-b')!.left, 1e-6));
    });

    test('distribute spreads three elements evenly', () async {
      final surface = _Surface()..selection = {'el-a', 'el-b', 'el-g'};
      await surface.run('distribute.horizontal');
      final geometry = SceneGeometry.of(surface.document, 0);
      final rects = <Rect>[
        for (final id in ['el-a', 'el-b', 'el-g']) geometry.rectOf(id)!,
      ]..sort((a, b) => a.center.dx.compareTo(b.center.dx));
      final firstGap = rects[1].left - rects[0].right;
      final secondGap = rects[2].left - rects[1].right;
      expect(firstGap, closeTo(secondGap, 1e-6));
    });
  });

  group('slide commands', () {
    test('add slide inserts a blank one after the current and shows it', () async {
      final surface = _Surface();
      await surface.run('slide.add');
      expect(surface.document.sceneCount, 4);
      expect(surface.document.elementIdsInScene(1), isEmpty);
      expect(surface.shownSlide, 1);
    });

    test('duplicate slide re-mints its element ids', () async {
      final surface = _Surface();
      await surface.run('slide.duplicate');
      expect(surface.document.sceneCount, 4);
      final copies = surface.document.elementIdsInScene(1);
      expect(copies, hasLength(3));
      expect(copies.toSet().intersection({'el-a', 'el-b', 'el-g'}), isEmpty);
      expect(surface.shownSlide, 1);
    });

    test('delete slide clamps the shown slide', () async {
      final surface = _Surface();
      await surface.run('slide.delete', slide: 2);
      expect(surface.document.sceneCount, 2);
      expect(surface.shownSlide, 1);
    });

    test('move up and move down follow the slide', () async {
      final surface = _Surface();
      await surface.run('slide.moveDown');
      expect(surface.document.elementIdsInScene(1), ['el-a', 'el-b', 'el-g']);
      expect(surface.shownSlide, 1);
      await surface.run('slide.moveUp', slide: 1);
      expect(surface.document.elementIdsInScene(0), ['el-a', 'el-b', 'el-g']);
      expect(surface.shownSlide, 0);
    });
  });

  group('slide sections', () {
    test('start section marks the tile slide and names it in sequence', () async {
      final surface = _Surface();
      await surface.run('slide.section', slide: 1);
      expect(surface.document.sceneMeta(1)['section'], {'name': 'Section 1'});
      await surface.run('slide.section', slide: 2);
      expect(surface.document.sceneMeta(2)['section'], {'name': 'Section 2'});
    });

    test('an already-marked slide disables the command and a direct execute no-ops', () async {
      final surface = _Surface();
      surface.history.dispatch(
        const SetSceneMetaCommand(
          index: 1,
          meta: {
            'section': {'name': 'Intro'},
          },
        ),
      );
      expect(editorCommandById('slide.section').enabled(surface.scope(slide: 1)), isFalse);
      await surface.run('slide.section', slide: 1);
      expect(surface.document.sceneMeta(1)['section'], {'name': 'Intro'});
    });
  });

  group('slide clipboard', () {
    test('copy slide writes the scene and its meta, minus the section marker', () async {
      final surface = _Surface();
      surface.history.dispatch(
        const SetSceneMetaCommand(
          index: 0,
          meta: {
            'guides': [
              {'axis': 'vertical', 'pos': 0.5},
            ],
            'section': {'name': 'Intro'},
          },
        ),
      );
      await surface.run('slide.copy');
      final envelope = await surface.clipboard.read();
      expect(envelope, isNotNull);
      expect(envelope!.kind, 'slides');
      expect(envelope.slides.single.scene, surface.document.sceneJson(0));
      expect(envelope.slides.single.meta, {
        'guides': [
          {'axis': 'vertical', 'pos': 0.5},
        ],
      });
    });

    test('paste slide lands after the tile, ids fresh, meta carried, one undo step', () async {
      final surface = _Surface();
      surface.history.dispatch(
        const SetSceneMetaCommand(
          index: 0,
          meta: {
            'guides': [
              {'axis': 'horizontal', 'pos': 0.25},
            ],
          },
        ),
      );
      await surface.run('slide.copy');
      final undosBeforePaste = surface.history.canRedo;
      expect(undosBeforePaste, isFalse);
      await surface.run('slide.paste');
      expect(surface.document.sceneCount, 4);
      expect(surface.shownSlide, 1);
      final pasted = surface.document.elementIdsInScene(1);
      expect(pasted, hasLength(3));
      expect(pasted.toSet().intersection({'el-a', 'el-b', 'el-g'}), isEmpty);
      final pastedGroupChildren = surface.document.childIdsOfGroup(pasted[2]);
      expect(pastedGroupChildren.single, isNot('el-gc'));
      // The anchor collides with the original slide's, so it re-mints and
      // the in-set trigger reference follows.
      final pastedA = surface.document.elementJson(pasted[0])!;
      final pastedB = surface.document.elementJson(pasted[1])!;
      expect(pastedA['anchor'], 'intro-2');
      final animate = pastedB['animate']! as List<Object?>;
      final at = (animate.single! as Map<String, Object?>)['at']! as Map<String, Object?>;
      expect(at['anchor'], 'intro-2');
      // The guides came along on the new slide.
      expect(surface.document.sceneMeta(1)['guides'], [
        {'axis': 'horizontal', 'pos': 0.25},
      ]);
      // One undo step removes the pasted slide and its meta.
      surface.history.undo();
      expect(surface.document.sceneCount, 3);
      expect(surface.document.sceneMeta(1), isEmpty);
    });

    test('cross-deck slide paste travels the shared clipboard, ids re-minted', () async {
      final clipboard = EditorClipboard();
      final source = _Surface(clipboard: clipboard);
      await source.run('slide.copy');
      final target = _Surface(
        clipboard: clipboard,
        deck: {
          'fluvieSpec': 1,
          'size': {'width': 320, 'height': 180},
          'fps': 30,
          'scenes': [
            {
              'duration': '60f',
              'children': [
                {'id': 'el-a', 'type': 'Box', 'color': '#FFFFFF', 'anchor': 'intro'},
              ],
            },
          ],
        },
      );
      await target.run('slide.paste');
      expect(target.document.sceneCount, 2);
      final pasted = target.document.elementIdsInScene(1);
      expect(pasted, hasLength(3));
      expect(pasted.toSet().intersection({'el-a', 'el-b', 'el-g'}), isEmpty);
      // The target already declares "intro", so the pasted anchor re-mints.
      expect(target.document.elementJson(pasted[0])!['anchor'], 'intro-2');
      expect(target.shownSlide, 1);
      // The source deck never changed.
      expect(source.document.sceneCount, 3);
    });

    test('elements paste ignores a slides envelope and the other way round', () async {
      final surface = _Surface()..selection = {'el-a'};
      await surface.run('slide.copy');
      await surface.run('edit.paste');
      expect(surface.document.elementIdsInScene(0), hasLength(3));
      await surface.run('edit.copy');
      await surface.run('slide.paste');
      expect(surface.document.sceneCount, 3);
      expect(surface.history.canUndo, isFalse);
    });

    test('paste slide with an empty clipboard is a no-op', () async {
      final surface = _Surface();
      await surface.run('slide.paste');
      expect(surface.history.canUndo, isFalse);
    });

    test('copy and paste slide without a clipboard are no-ops', () async {
      final surface = _Surface();
      final scope = CommandScope(
        document: surface.document,
        slide: 0,
        dispatch: surface.history.dispatch,
      );
      await editorCommandById('slide.copy').execute(scope);
      await editorCommandById('slide.paste').execute(scope);
      expect(surface.history.canUndo, isFalse);
    });
  });

  group('defensive guards (execute without enabled)', () {
    test('no-op executions never dirty the history', () async {
      // Every caller checks enabled() first; a direct execute against an
      // insufficient scope must still change nothing.
      final surface = _Surface();
      await surface.run('edit.duplicate');
      await surface.run('edit.delete');
      surface.selection = {'el-a'};
      await surface.run('arrange.group');
      await surface.run('arrange.ungroup');
      await surface.run('distribute.horizontal');
      surface.selection = const {};
      await surface.run('slide.moveUp');
      await surface.run('slide.moveDown', slide: 2);
      expect(surface.history.canUndo, isFalse);
    });

    test('copy and paste without a clipboard are no-ops', () async {
      final surface = _Surface();
      final scope = CommandScope(
        document: surface.document,
        slide: 0,
        selection: const {'el-a'},
        dispatch: surface.history.dispatch,
      );
      await editorCommandById('edit.copy').execute(scope);
      await editorCommandById('edit.paste').execute(scope);
      expect(surface.history.canUndo, isFalse);
    });

    test('align without resolved rects is a no-op', () async {
      final surface = _Surface();
      final scope = CommandScope(
        document: surface.document,
        slide: 0,
        selection: const {'el-a'},
        dispatch: surface.history.dispatch,
      );
      await editorCommandById('align.left').execute(scope);
      expect(surface.history.canUndo, isFalse);
    });

    test('group with unresolved geometry is a no-op', () async {
      final surface = _Surface();
      final scope = CommandScope(
        document: surface.document,
        slide: 0,
        selection: const {'el-a', 'el-b'},
        dispatch: surface.history.dispatch,
      );
      await editorCommandById('arrange.group').execute(scope);
      expect(surface.history.canUndo, isFalse);
    });

    test('delete slide on a one-slide deck is a no-op', () async {
      final surface = _Surface(
        deck: {
          'fluvieSpec': 1,
          'size': {'width': 320, 'height': 180},
          'fps': 30,
          'scenes': [
            {'duration': '60f', 'children': <Object?>[]},
          ],
        },
      );
      await surface.run('slide.delete');
      expect(surface.history.canUndo, isFalse);
    });
  });

  group('scope size helpers', () {
    test('an entered group frames its commands', () {
      final document = EditorDocument.fromJson(_deck());
      final scope = CommandScope(
        document: document,
        slide: 0,
        enteredGroup: 'el-g',
        frameOrigin: groupFrameRect(document, 'el-g')!.topLeft,
        frameSize: groupFrameRect(document, 'el-g')!.size,
        dispatch: (_) {},
      );
      expect(scope.frameSize, const Size(128, 36));
    });
  });
}
