import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/tools/media_importer.dart';

/// Every media source [document] references, first-seen order, each once —
/// the asset panel's reuse list. Clip sources are flagged as video; posters
/// and images are not.
List<MediaPick> usedMediaSources(EditorDocument document) {
  final seen = <String>{};
  final picks = <MediaPick>[];
  void add(Object? raw, {required bool isVideo}) {
    if (raw is! Map<String, Object?>) return;
    final key = '${raw['kind']}|${raw['value']}';
    if (!seen.add(key)) return;
    picks.add(MediaPick(source: Map<String, Object?>.of(raw), isVideo: isVideo));
  }

  for (var scene = 0; scene < document.sceneCount; scene++) {
    for (final id in document.elementIdsInScene(scene)) {
      final element = document.elementJson(id);
      if (element == null) continue;
      switch (element['type']) {
        case 'Image':
          add(element['source'], isVideo: false);
        case 'Clip':
          add(element['source'], isVideo: true);
          add(element['poster'], isVideo: false);
      }
    }
  }
  return picks;
}
