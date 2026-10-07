import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/animation_builder.dart';
import 'package:fluvie/src/serialization/animation_spec.dart';
import 'package:fluvie/src/serialization/effect_spec.dart';
import 'package:fluvie/src/serialization/element_spec.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

/// The coverage matrix over the whole spec surface: every element type and
/// every animation preset the codecs know must appear in at least one corpus
/// fixture, round-trip through its codec, and build. A future codec cannot
/// land without a fixture — the set-difference assertions name the gap.
void main() {
  final corpus =
      Directory('test/serialization/corpus')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.fluvie.json'))
          .toList(growable: false)
        ..sort((a, b) => a.path.compareTo(b.path));

  final documents = <String, Map<String, Object?>>{
    for (final file in corpus)
      file.uri.pathSegments.last: jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
  };

  // One representative element node per type, and the set of presets named in
  // any fixture's animate list (both walks recurse into wrapper children).
  final elementByType = <String, Map<String, Object?>>{};
  final coveredPresets = <String>{};
  final coveredEffectKinds = <String>{};
  for (final document in documents.values) {
    for (final element in _elements(document)) {
      final type = element['type'];
      if (type is String) elementByType.putIfAbsent(type, () => element);
      final effects = element['effects'];
      if (effects is List) {
        for (final effect in effects) {
          if (effect is Map<String, Object?> && effect['kind'] is String) {
            coveredEffectKinds.add(effect['kind']! as String);
          }
        }
      }
      final animate = element['animate'];
      if (animate is! List) continue;
      for (final entry in animate) {
        if (entry is Map<String, Object?> && entry['preset'] is String) {
          coveredPresets.add(entry['preset']! as String);
        }
      }
    }
  }

  group('element coverage', () {
    test('every known element type appears in at least one corpus fixture', () {
      final missing = knownElementTypes.difference(elementByType.keys.toSet());
      expect(
        missing,
        isEmpty,
        reason:
            'These element types have no corpus fixture: ${missing.join(', ')}. '
            'Add each to a fixture under test/serialization/corpus.',
      );
    });

    for (final type in knownElementTypes.toList()..sort()) {
      final element = elementByType[type];
      if (element == null) continue; // The set-difference test above names it.

      test('$type round-trips through ElementSpec identically', () {
        final once = ElementSpec.fromJson(element, AnchorTable()).toJson();
        final twice = ElementSpec.fromJson(once, AnchorTable()).toJson();
        expect(twice, once);
      });

      test('a document holding a $type builds a Video', () {
        final document = <String, Object?>{
          'fluvieSpec': 1,
          'scenes': [
            {
              'duration': '60f',
              'layout': 'canvas',
              'children': [element],
            },
          ],
        };
        expect(VideoSpec.fromJson(document).build(), isA<Video>());
      });
    }
  });

  group('effect coverage', () {
    test('every effect kind appears in at least one corpus fixture', () {
      final missing = EffectSpecKind.values.map((k) => k.name).toSet()
        ..removeAll(coveredEffectKinds);
      expect(
        missing,
        isEmpty,
        reason:
            'These effect kinds have no corpus fixture: ${missing.join(', ')}. '
            'Add each to a fixture under test/serialization/corpus.',
      );
    });
  });

  group('preset coverage', () {
    test('every known animation preset appears in at least one corpus fixture', () {
      final missing = knownAnimationPresets.difference(coveredPresets);
      expect(
        missing,
        isEmpty,
        reason:
            'These animation presets appear in no corpus fixture animate list: '
            '${missing.join(', ')}. Add each to a fixture under '
            'test/serialization/corpus.',
      );
    });

    test('the minimal-args table names every known preset exactly', () {
      expect(_minimalPresetArgs.keys.toSet(), knownAnimationPresets);
    });

    for (final entry in _minimalPresetArgs.entries) {
      test('${entry.key} builds from its minimal args form', () {
        final anchors = AnchorTable();
        final spec = AnimationSpec.fromJson({
          'preset': entry.key,
          ...entry.value,
        }, anchors);
        expect(() => buildAnimation(spec, anchors), returnsNormally);
      });
    }
  });

  group('digest stability across the full corpus', () {
    for (final entry in documents.entries) {
      test('${entry.key} digests deterministically and survives a round-trip', () {
        final spec = VideoSpec.fromJson(entry.value);
        expect(spec.digest(), spec.digest(), reason: 'digest() must be pure');
        final reparsed = VideoSpec.fromJson(spec.toJson());
        expect(reparsed.digest(), spec.digest(), reason: 'a round-trip must not move the digest');
      });
    }
  });
}

/// Every element node in [document]: each scene child plus, recursively, the
/// nested `child` of every wrapper element and the `children` of every group.
Iterable<Map<String, Object?>> _elements(Map<String, Object?> document) sync* {
  final scenes = document['scenes'];
  if (scenes is! List) return;
  for (final scene in scenes) {
    if (scene is! Map<String, Object?>) continue;
    final children = scene['children'];
    if (children is! List) continue;
    for (final child in children) {
      if (child is Map<String, Object?>) yield* _withNested(child);
    }
  }
}

Iterable<Map<String, Object?>> _withNested(Map<String, Object?> element) sync* {
  yield element;
  final child = element['child'];
  if (child is Map<String, Object?>) yield* _withNested(child);
  final children = element['children'];
  if (children is! List) return;
  for (final nested in children) {
    if (nested is Map<String, Object?>) yield* _withNested(nested);
  }
}

/// The smallest JSON argument form that builds each preset: empty where every
/// argument has a default, and exactly the required arguments elsewhere.
const Map<String, Map<String, Object?>> _minimalPresetArgs = {
  'fadeIn': {},
  'fadeOut': {},
  'slideIn': {},
  'slideOut': {},
  'slideFadeIn': {},
  'slideFadeOut': {},
  'pop': {},
  'scaleIn': {},
  'scaleOut': {},
  'blurIn': {},
  'blurOut': {},
  'grain': {},
  'vignette': {},
  'spin': {},
  'drift': {},
  'kenBurns': {},
  'maskWipeIn': {},
  'maskWipeOut': {},
  'glitchIn': {},
  'glitchOut': {},
  'float': {},
  'pulse': {},
  'scanlines': {},
  'chromatic': {},
  'bloom': {},
  'parallax': {},
  'color': {'to': '#FFD166'},
  'gradientShift': {
    'to': ['#101018', '#3C1E5A'],
  },
  'particles': {
    'spec': {'kind': 'confetti'},
  },
  'shader': {'asset': 'shaders/ripple.frag'},
  'scaleY': {'on': 'bass'},
  'along': {'path': 'M 0 0 L 40 40'},
};
