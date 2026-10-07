import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show ThemeSpec;
import 'package:fluvie_editor/fluvie_editor.dart';

/// A deck bound to every shared token name the builtin themes promise, so
/// applying any of them must resolve cleanly.
Map<String, Object?> _boundDeck(Map<String, Object?> theme) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': theme,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'background': {
        'kind': 'color',
        'color': {'token': 'background'},
      },
      'children': [
        {
          'id': 'el-panel',
          'type': 'Box',
          'color': {'token': 'surface'},
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.9, 'h': 0.8},
        },
        {
          'id': 'el-accent',
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.5, 'y': 0.8, 'w': 0.4, 'h': 0.1},
        },
        for (final (i, token) in ['title', 'heading', 'body', 'caption'].indexed)
          {
            'id': 'el-$token',
            'type': 'Text',
            'text': token,
            'style': {
              'token': token,
              'color': {'token': i.isEven ? 'text' : 'muted'},
            },
            'transform': {'x': 0.5, 'y': 0.15 + i * 0.18, 'w': 0.8, 'h': 0.15},
          },
      ],
    },
  ],
};

void main() {
  test('three starter themes exist: midnight, paper, neon', () {
    expect(builtinThemes.keys, ['midnight', 'paper', 'neon']);
  });

  test('every builtin theme parses as a valid ThemeSpec', () {
    for (final entry in builtinThemes.entries) {
      final theme = ThemeSpec.fromJson(entry.value);
      expect(theme.palette, isNotEmpty, reason: entry.key);
      expect(theme.typeScale, isNotEmpty, reason: entry.key);
      expect(theme.spacing, isNotEmpty, reason: entry.key);
      expect(theme.motion, isNotNull, reason: entry.key);
    }
  });

  test('the themes share one token vocabulary, so switching restyles', () {
    final names = [
      for (final theme in builtinThemes.values)
        (
          ((theme['palette']! as Map).keys.toList()..sort()).join(','),
          ((theme['typeScale']! as Map).keys.toList()..sort()).join(','),
          ((theme['spacing']! as Map).keys.toList()..sort()).join(','),
        ),
    ];
    expect(names.toSet(), hasLength(1));
  });

  test('palette and typeScale names never collide, so renames stay honest', () {
    for (final theme in builtinThemes.values) {
      final palette = (theme['palette']! as Map).keys.toSet();
      final typeScale = (theme['typeScale']! as Map).keys.toSet();
      expect(palette.intersection(typeScale), isEmpty);
    }
  });

  test('a deck bound to the shared tokens builds under every theme', () {
    for (final theme in builtinThemes.values) {
      final document = EditorDocument.fromJson(_boundDeck(theme));
      expect(document.spec.build, returnsNormally);
    }
  });
}
