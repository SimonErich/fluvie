part of 'editor_document.dart';

/// The auto-animate mutations, over the reads in
/// [EditorDocumentAutoAnimate]. Every method returns a new document, so a
/// command wrapping one is one undo step.
extension EditorDocumentAutoAnimateEdits on EditorDocument {
  /// Turns auto-animate on for [slide]: clears any earlier application,
  /// runs the pairing engine against the previous slide, writes one minted
  /// `hero-N` id onto both sides of every content pair (explicit author
  /// pairs already carry theirs), and — when no authored transition governs
  /// the boundary — writes a crossFade `enter` so the morph has a blend
  /// window. Everything applied is tracked in the slide's editor metadata,
  /// so [clearAutoAnimate] removes exactly what this added.
  EditorDocument applyAutoAnimate(int slide) {
    var document = clearAutoAnimate(slide);
    final minted = <String>[];
    if (slide > 0) {
      for (final pair in document.autoAnimatePairing(slide).pairs) {
        if (pair.source != SharedPairSource.content) continue;
        final id = document._mintSharedId();
        minted.add(id);
        document = document._withSharedId(pair.previousId, id)._withSharedId(pair.currentId, id);
      }
    }
    final autoEnter = slide > 0 && !document._boundaryGoverned(slide);
    if (autoEnter) document = document.updateScene(slide, {'enter': _autoEnterJson});
    return document.setSceneMeta(slide, {
      'autoAnimate': true,
      'autoShared': minted.isEmpty ? null : minted,
      'autoEnter': autoEnter ? true : null,
    });
  }

  /// Turns auto-animate off for [slide]: the tracked auto-minted `shared`
  /// ids leave every element carrying them, the auto-written `enter` leaves
  /// when it is still exactly the auto value, and the tracking metadata
  /// goes with them. Author-typed shared ids and authored transitions stay.
  EditorDocument clearAutoAnimate(int slide) {
    final meta = sceneMeta(slide);
    final tracked = [...?(meta['autoShared'] as List?)?.whereType<String>()];
    final autoEnter = meta['autoEnter'] == true;
    if (!meta.containsKey('autoAnimate') && tracked.isEmpty && !autoEnter) return this;
    var document = tracked.isEmpty
        ? this
        : _mutate((json) {
            for (final scene
                in (json['scenes']! as List<Object?>).whereType<Map<String, Object?>>()) {
              for (final walked in _walkScene(scene)) {
                if (tracked.contains(walked.element['shared'])) walked.element.remove('shared');
              }
            }
          });
    if (autoEnter &&
        canonicalJson(document.sceneJson(slide)['enter']) == canonicalJson(_autoEnterJson)) {
      document = document.updateScene(slide, {'enter': null});
    }
    return document._withoutAutoAnimateMeta(slide);
  }

  /// Manually pairs [currentId] (on [slide]) with [previousId] (on the
  /// slide before): reuses the previous element's shared id when it has
  /// one, mints a fresh author-level `hero-N` otherwise, and writes it on
  /// both sides. Manual links are not tracked as auto, so they survive
  /// [clearAutoAnimate]. An existing pairing of [currentId] dissolves
  /// first.
  EditorDocument linkShared({
    required int slide,
    required String currentId,
    required String previousId,
  }) {
    var document = unlinkShared(slide: slide, elementId: currentId);
    final existing = document.elementJson(previousId)?['shared'];
    final shared = existing is String ? existing : document._mintSharedId();
    if (existing is! String) document = document._withSharedId(previousId, shared);
    return document._withSharedId(currentId, shared);
  }

  /// Breaks [elementId]'s pairing: its `shared` id leaves the element. An
  /// auto-tracked id dissolves fully — the previous-slide partner drops it
  /// too and the tracking forgets it — while an author-typed id stays on
  /// every other element carrying it.
  EditorDocument unlinkShared({required int slide, required String elementId}) {
    final shared = elementJson(elementId)?['shared'];
    if (shared is! String) return this;
    final tracked = [...?(sceneMeta(slide)['autoShared'] as List?)?.whereType<String>()];
    var document = _withoutSharedId(elementId);
    if (!tracked.contains(shared)) return document;
    final partner = slide == 0 ? null : _sharedCarrierIn(slide - 1, shared);
    if (partner != null) document = document._withoutSharedId(partner);
    final rest = [
      for (final id in tracked)
        if (id != shared) id,
    ];
    return document.setSceneMeta(slide, {'autoShared': rest.isEmpty ? null : rest});
  }

  /// Drops the auto-animate tracking keys of [slide] and prunes the empty
  /// containers they may leave, so a toggle on-and-off restores the
  /// document it started from.
  EditorDocument _withoutAutoAnimateMeta(int slide) => _mutate((json) {
    final editor = json['editor'];
    if (editor is! Map<String, Object?>) return;
    final scenes = editor['scenes'];
    if (scenes is! Map<String, Object?>) return;
    final meta = scenes['$slide'];
    if (meta is Map<String, Object?>) {
      meta
        ..remove('autoAnimate')
        ..remove('autoShared')
        ..remove('autoEnter');
      if (meta.isEmpty) scenes.remove('$slide');
    }
    if (scenes.isEmpty) editor.remove('scenes');
    if (editor.length == 1 && editor.containsKey('editorSchema')) json.remove('editor');
  });

  /// Whether any authored transition governs the boundary into [slide] —
  /// the compositor's own precedence: the incoming scene's `enter`, the
  /// outgoing scene's `exit`, the video default.
  bool _boundaryGoverned(int slide) =>
      sceneJson(slide)['enter'] != null ||
      sceneJson(slide - 1)['exit'] != null ||
      toJson()['transition'] != null;

  /// The lowest free `hero-N` over every `shared` id in the document.
  String _mintSharedId() {
    final used = <Object?>{
      for (final scene in _scenes.whereType<Map<String, Object?>>())
        for (final walked in _walkScene(scene)) walked.element['shared'],
    };
    var counter = 1;
    while (used.contains('hero-$counter')) {
      counter++;
    }
    return 'hero-$counter';
  }

  EditorDocument _withSharedId(String id, String shared) =>
      replaceElement(id, {...elementJson(id)!, 'shared': shared});

  EditorDocument _withoutSharedId(String id) =>
      replaceElement(id, {...elementJson(id)!}..remove('shared'));
}
