import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';

Map<String, Object?> _deck({Map<String, Object?>? theme}) => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'theme': ?theme,
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
          'id': 'el-box',
          'type': 'Box',
          'color': {'token': 'accent'},
          'transform': {'x': 0.5, 'y': 0.5, 'w': 0.4, 'h': 0.3},
        },
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Hello',
          'style': {'token': 'title', 'fontSize': 40},
          'transform': {'x': 0.5, 'y': 0.2, 'w': 0.8, 'h': 0.2},
        },
      ],
    },
  ],
};

Map<String, Object?> _theme() => {
  'palette': {'background': '#101018', 'accent': '#6C5CE7'},
  'typeScale': {
    'title': {'fontSize': 48, 'fontWeight': 'w700'},
  },
  'spacing': {'m': 24.0},
  'motion': {'duration': '300ms', 'ease': 'out'},
};

void main() {
  group('EditorDocumentTheme', () {
    test('themeJson reads the theme block and empty when there is none', () {
      final themed = EditorDocument.fromJson(_deck(theme: _theme()));
      expect(themed.themeJson?['palette'], {'background': '#101018', 'accent': '#6C5CE7'});
      expect(EditorDocument.fromJson(_deck()).themeJson, isNull);
    });

    test('themeJson is a copy: mutating it never touches the document', () {
      final document = EditorDocument.fromJson(_deck(theme: _theme()));
      document.themeJson!['palette'] = null;
      expect(document.themeJson?['palette'], isNotNull);
    });

    test('themeTokenReferenced sees color, style, and nested references', () {
      final document = EditorDocument.fromJson(_deck(theme: _theme()));
      expect(document.themeTokenReferenced('background'), isTrue);
      expect(document.themeTokenReferenced('accent'), isTrue);
      expect(document.themeTokenReferenced('title'), isTrue);
      expect(document.themeTokenReferenced('unused'), isFalse);
    });

    test('renameThemeToken moves the entry and rewrites every reference', () {
      final document = EditorDocument.fromJson(
        _deck(theme: _theme()),
      ).renameThemeToken(map: 'palette', from: 'accent', to: 'brand');
      final palette = (document.themeJson!['palette']! as Map).cast<String, Object?>();
      expect(palette.containsKey('accent'), isFalse);
      expect(palette['brand'], '#6C5CE7');
      expect(document.elementJson('el-box')?['color'], {'token': 'brand'});
      // The unrelated background reference stays put.
      final scene = document.sceneJson(0);
      expect((scene['background']! as Map)['color'], {'token': 'background'});
    });

    test('renameThemeToken rewrites style tokens with sibling fields intact', () {
      final document = EditorDocument.fromJson(
        _deck(theme: _theme()),
      ).renameThemeToken(map: 'typeScale', from: 'title', to: 'display');
      final typeScale = (document.themeJson!['typeScale']! as Map).cast<String, Object?>();
      expect(typeScale.containsKey('title'), isFalse);
      expect(typeScale['display'], {'fontSize': 48, 'fontWeight': 'w700'});
      expect(document.elementJson('el-title')?['style'], {'token': 'display', 'fontSize': 40});
    });

    test('renameThemeToken throws for an unknown entry', () {
      final document = EditorDocument.fromJson(_deck(theme: _theme()));
      expect(
        () => document.renameThemeToken(map: 'palette', from: 'missing', to: 'other'),
        throwsArgumentError,
      );
    });
  });

  group('SetThemeCommand', () {
    test('writes the theme block undoably', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(SetThemeCommand(theme: _theme()));
      expect(history.document.themeJson?['spacing'], {'m': 24.0});
      expect(history.undoLabel, 'Edit theme');
      history.undo();
      expect(history.document.themeJson, isNull);
    });

    test('null clears the theme block', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck(theme: _theme())))
        ..dispatch(const SetThemeCommand(theme: null));
      expect(history.document.themeJson, isNull);
      expect(history.document.toJson().containsKey('theme'), isFalse);
    });

    test('a merge group coalesces a picker drag into one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck(theme: _theme())));
      final drag = _theme();
      for (final hex in ['#111111', '#222222', '#333333']) {
        (drag['palette']! as Map<String, Object?>)['accent'] = hex;
        history.dispatch(
          SetThemeCommand(
            theme: {
              for (final entry in drag.entries)
                entry.key: entry.value is Map
                    ? Map<String, Object?>.from(entry.value! as Map)
                    : entry.value,
            },
            mergeGroup: 'palette-accent',
          ),
        );
      }
      final palette = (history.document.themeJson!['palette']! as Map).cast<String, Object?>();
      expect(palette['accent'], '#333333');
      history.undo();
      expect(
        (history.document.themeJson!['palette']! as Map).cast<String, Object?>()['accent'],
        '#6C5CE7',
        reason: 'one undo lands before the whole drag',
      );
    });

    test('the apply verb names the start-from step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck()))
        ..dispatch(SetThemeCommand(theme: _theme(), verb: 'Apply'));
      expect(history.undoLabel, 'Apply theme');
    });
  });

  group('RenameThemeTokenCommand', () {
    test('renames the token and its references in one undo step', () {
      final history = DocumentHistory(EditorDocument.fromJson(_deck(theme: _theme())))
        ..dispatch(const RenameThemeTokenCommand(map: 'palette', from: 'accent', to: 'brand'));
      expect(history.document.elementJson('el-box')?['color'], {'token': 'brand'});
      expect(history.undoLabel, 'Rename token');
      history.undo();
      expect(history.document.elementJson('el-box')?['color'], {'token': 'accent'});
      final palette = (history.document.themeJson!['palette']! as Map).cast<String, Object?>();
      expect(palette['accent'], '#6C5CE7');
    });
  });
}
