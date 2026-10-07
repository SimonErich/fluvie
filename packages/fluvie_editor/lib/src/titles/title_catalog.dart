import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fluvie_editor/src/document/editor_document.dart';
import 'package:fluvie_editor/src/templates/template_merge.dart';
import 'package:fluvie_editor/src/video_mode/video_timebase.dart';

/// A data-authored title composition and its additive token dependencies.
final class TitleTemplate {
  /// Parses one bundled title fixture.
  TitleTemplate.fromJson(this.json);

  /// The fixture, including children, theme and optional masters.
  final Map<String, Object?> json;

  /// The title shown in the browser.
  String get name => json['name']! as String;

  /// Its composition family.
  String get family => json['family']! as String;

  /// Mints stable ids, sets a scene-local window at the playhead and keeps
  /// the title inside the scene. All children share the same authored window.
  Map<String, Object?> prepare(EditorDocument document, int scene, int frame, {String? lane}) {
    final duration = VideoTimebase.of(document).sceneSpans[scene].durationFrames;
    final start = frame.clamp(0, duration - 1);
    final end = (start + document.spec.fps * 3).clamp(start + 1, duration);
    final prepared = preparedTemplateScene(document, {'children': json['children']});
    final children = (prepared['children']! as List).cast<Map<String, Object?>>();
    for (final child in children) {
      child['show'] = {'from': '${start}f', 'to': '${end}f'};
      if (lane != null) child['lane'] = lane;
    }
    return {...json, 'children': children};
  }
}

/// Reads the four shipped JSON compositions, without document side effects.
Future<List<TitleTemplate>> loadTitleCatalog({AssetBundle? bundle}) async {
  final source = bundle ?? rootBundle;
  return [
    for (final file in ['lower_third', 'full_screen', 'credits', 'callout'])
      TitleTemplate.fromJson(
        jsonDecode(await source.loadString('packages/fluvie_editor/assets/titles/$file.json'))
            as Map<String, Object?>,
      ),
  ];
}
