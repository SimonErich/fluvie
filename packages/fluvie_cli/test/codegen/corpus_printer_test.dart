import 'dart:convert';
import 'dart:io';

import 'package:dart_style/dart_style.dart';
import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

/// Every element type the spec knows, mirrored from fluvie's
/// `knownElementTypes` (the CLI is pure Dart and cannot import the Flutter
/// package, so the vocabulary is pinned here and checked against the corpus).
const Set<String> _specElementTypes = {
  'Text',
  'Box',
  'Image',
  'Counter',
  'Shape',
  'Arrow',
  'Connector',
  'Clip',
  'Typewriter',
  'Markdown',
  'Terminal',
  'Code',
  'Chart',
  'Mermaid',
  'WebView',
  'Html',
  'Bars',
  'LowerThird',
  'TitleCard',
  'Snapshot',
  'DeviceFrame',
  'Callout',
  'Spotlight',
  'Group',
};

/// Every animation preset the spec knows, mirrored from fluvie's
/// `knownAnimationPresets` (same pinning rule as [_specElementTypes]).
const Set<String> _specAnimationPresets = {
  'fadeIn',
  'fadeOut',
  'slideIn',
  'slideOut',
  'slideFadeIn',
  'slideFadeOut',
  'pop',
  'scaleIn',
  'scaleOut',
  'blurIn',
  'blurOut',
  'grain',
  'vignette',
  'spin',
  'drift',
  'kenBurns',
  'maskWipeIn',
  'maskWipeOut',
  'glitchIn',
  'glitchOut',
  'float',
  'pulse',
  'color',
  'gradientShift',
  'scanlines',
  'chromatic',
  'bloom',
  'parallax',
  'particles',
  'shader',
  'scaleY',
  'along',
};

/// The printer half of the conformance corpus: every fixture fluvie accepts
/// must print to syntactically valid Dart (the formatter parses it), so the
/// JSON codecs and the Dart printer stay in lockstep — and every element type
/// and animation preset the spec knows must appear in a fixture the printer
/// prints successfully, so a codec cannot land without printer coverage.
void main() {
  final corpus = Directory('../fluvie/test/serialization/corpus')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.fluvie.json'))
      .toList(growable: false);

  test('the corpus is visible from the printer', () {
    expect(corpus, isNotEmpty);
  });

  for (final file in corpus) {
    test('${file.uri.pathSegments.last} prints to valid Dart', () {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final code = printVideoSpecJson(json);
      final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
      expect(() => formatter.format(code), returnsNormally);
    });
  }

  group('the printer covers the whole spec vocabulary', () {
    // Coverage counts only fixtures the printer turns into parseable Dart, so
    // a gap fails here with a named type/preset instead of silently passing
    // through a fixture the printer cannot handle.
    final coveredTypes = <String>{};
    final coveredPresets = <String>{};
    final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
    for (final file in corpus) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      try {
        formatter.format(printVideoSpecJson(json));
      } on Object {
        continue; // The per-fixture test above reports the failure by name.
      }
      _collect(json, coveredTypes, coveredPresets);
    }

    test('every element type appears in a fixture that prints', () {
      final missing = _specElementTypes.difference(coveredTypes);
      expect(
        missing,
        isEmpty,
        reason:
            'These element types are in no printable corpus fixture: '
            '${missing.join(', ')}',
      );
    });

    test('every animation preset appears in a fixture that prints', () {
      final missing = _specAnimationPresets.difference(coveredPresets);
      expect(
        missing,
        isEmpty,
        reason:
            'These animation presets are in no printable corpus fixture: '
            '${missing.join(', ')}',
      );
    });
  });
}

/// Walks one fixture document, adding every element `type` (recursing into
/// wrapper `child` nodes and group `children` lists) and every `animate`
/// entry's `preset` to the sets.
void _collect(Map<String, Object?> document, Set<String> types, Set<String> presets) {
  final scenes = document['scenes'];
  if (scenes is! List) return;
  for (final scene in scenes) {
    if (scene is! Map<String, Object?>) continue;
    final children = scene['children'];
    if (children is! List) continue;
    for (final child in children) {
      if (child is Map<String, Object?>) _collectElement(child, types, presets);
    }
  }
}

void _collectElement(Map<String, Object?> element, Set<String> types, Set<String> presets) {
  final type = element['type'];
  if (type is String) types.add(type);
  final animate = element['animate'];
  if (animate is List) {
    for (final entry in animate) {
      if (entry is Map<String, Object?> && entry['preset'] is String) {
        presets.add(entry['preset']! as String);
      }
    }
  }
  final child = element['child'];
  if (child is Map<String, Object?>) _collectElement(child, types, presets);
  final children = element['children'];
  if (children is! List) return;
  for (final nested in children) {
    if (nested is Map<String, Object?>) _collectElement(nested, types, presets);
  }
}
