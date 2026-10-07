part of 'command_registry.dart';

/// The slide commands: the slide clipboard, add, duplicate, delete,
/// sections, and the strip's moves.
final List<EditorCommandEntry> _slideCommands = [
  EditorCommandEntry(
    id: 'slide.copy',
    title: 'Copy slide',
    category: 'Slides',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.clipboard != null,
    execute: (scope) async {
      final clipboard = scope.clipboard;
      if (clipboard == null) return;
      // The section marker stays home: a copied slide is a slide, not a
      // section boundary. Guides and the rest travel.
      final meta = {...scope.document.sceneMeta(scope.slide)}..remove('section');
      await clipboard.write(
        ClipboardEnvelope.slides([
          CopiedSlide(scene: scope.document.sceneJson(scope.slide), meta: meta),
        ]),
      );
    },
  ),
  EditorCommandEntry(
    id: 'slide.paste',
    title: 'Paste slide',
    category: 'Slides',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.clipboard != null,
    execute: (scope) async {
      final envelope = await scope.clipboard?.read();
      if (envelope == null || envelope.kind != 'slides' || envelope.slides.isEmpty) return;
      final scenes = _remintedScenes(scope.document, envelope.slides);
      for (var i = 0; i < scenes.length; i++) {
        scope.dispatch(
          AddSceneCommand(
            scene: scenes[i],
            at: scope.slide + 1 + i,
            meta: envelope.slides[i].meta.isEmpty ? null : envelope.slides[i].meta,
            verb: 'Paste',
          ),
        );
      }
      scope.showSlide(scope.slide + 1);
    },
  ),
  EditorCommandEntry(
    id: 'slide.add',
    title: 'Add slide',
    category: 'Slides',
    menus: const {EditorMenu.canvas},
    enabled: (_) => true,
    execute: (scope) async {
      scope.dispatch(
        AddSceneCommand(
          scene: const {'duration': '3s', 'children': <Object?>[]},
          at: scope.slide + 1,
        ),
      );
      scope.showSlide(scope.slide + 1);
    },
  ),
  EditorCommandEntry(
    id: 'slide.duplicate',
    title: 'Duplicate slide',
    category: 'Slides',
    menus: const {EditorMenu.canvas, EditorMenu.slideStrip},
    enabled: (_) => true,
    execute: (scope) async {
      scope.dispatch(
        AddSceneCommand(scene: scope.document.duplicatedScene(scope.slide), at: scope.slide + 1),
      );
      scope.showSlide(scope.slide + 1);
    },
  ),
  EditorCommandEntry(
    id: 'slide.delete',
    title: 'Delete slide',
    category: 'Slides',
    menus: const {EditorMenu.canvas, EditorMenu.slideStrip},
    destructive: true,
    enabled: (scope) => scope.document.sceneCount > 1,
    execute: (scope) async {
      final count = scope.document.sceneCount;
      if (count <= 1) return;
      scope.dispatch(RemoveSceneCommand(index: scope.slide));
      scope.showSlide(min(scope.slide, count - 2));
    },
  ),
  EditorCommandEntry(
    id: 'slide.moveUp',
    title: 'Move slide up',
    category: 'Slides',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.slide > 0,
    execute: (scope) async {
      if (scope.slide <= 0) return;
      scope.dispatch(ReorderSceneCommand(from: scope.slide, to: scope.slide - 1));
      scope.showSlide(max(scope.slide - 1, 0));
    },
  ),
  EditorCommandEntry(
    id: 'slide.moveDown',
    title: 'Move slide down',
    category: 'Slides',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.slide < scope.document.sceneCount - 1,
    execute: (scope) async {
      if (scope.slide >= scope.document.sceneCount - 1) return;
      scope.dispatch(ReorderSceneCommand(from: scope.slide, to: scope.slide + 1));
      scope.showSlide(scope.slide + 1);
    },
  ),
  EditorCommandEntry(
    id: 'slide.section',
    title: 'Start section here',
    category: 'Slides',
    menus: const {EditorMenu.slideStrip},
    enabled: (scope) => scope.document.sceneMeta(scope.slide)['section'] == null,
    execute: (scope) async {
      if (scope.document.sceneMeta(scope.slide)['section'] != null) return;
      final named = deckSections(scope.document).where((s) => s.name != null).length;
      scope.dispatch(
        SetSceneMetaCommand(
          index: scope.slide,
          meta: {
            'section': {'name': 'Section ${named + 1}'},
          },
        ),
      );
    },
  ),
];

/// Re-mints the copied scenes' element ids (nested group children included)
/// and colliding anchors against [document], sharing one fresh-id batch so
/// a multi-slide paste stays collision-free.
List<Map<String, Object?>> _remintedScenes(EditorDocument document, List<CopiedSlide> slides) {
  List<Map<String, Object?>> childrenOf(Map<String, Object?> scene) {
    final children = scene['children'];
    return children is List ? [...children.whereType<Map<String, Object?>>()] : const [];
  }

  final all = [for (final slide in slides) ...childrenOf(slide.scene)];
  var count = 0;
  void tally(Map<String, Object?> element) {
    count++;
    final children = element['children'];
    if (element['type'] == 'Group' && children is List) {
      children.whereType<Map<String, Object?>>().forEach(tally);
    }
  }

  all.forEach(tally);
  final fresh = document.nextIds(count).iterator;
  final mintAnchorId = _anchorMinter(document, all);
  return [
    for (final slide in slides)
      {
        ...slide.scene,
        'children': remintedElements(
          childrenOf(slide.scene),
          mintId: () => (fresh..moveNext()).current,
          mintAnchorId: mintAnchorId,
        ),
      },
  ];
}
