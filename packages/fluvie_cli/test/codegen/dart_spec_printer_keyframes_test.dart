import 'package:dart_style/dart_style.dart';
import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

Map<String, Object?> _animated(Map<String, Object?> animation) => {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'children': [
        {
          'type': 'Box',
          'color': '#6C5CE7',
          'animate': [animation],
        },
      ],
    },
  ],
};

void main() {
  group('the keyframes form prints its constructor call', () {
    test('stops print positionally as a Keyframe list', () {
      final code = printVideoSpecJson(
        _animated({
          'keyframes': [
            {'opacity': 0, 'y': 0.6},
            {'opacity': 1, 'y': 0},
          ],
        }),
      );
      expect(
        code,
        allOf(
          contains('Animation.keyframes('),
          contains('[Keyframe(opacity: 0, y: 0.6), Keyframe(opacity: 1, y: 0)]'),
        ),
      );
    });

    test('easings, positions, and phase print with their Dart names', () {
      final code = printVideoSpecJson(
        _animated({
          'keyframes': [
            {'opacity': 0},
            {'opacity': 1},
            {'y': 0},
          ],
          'easings': ['out', 'smooth'],
          'positions': ['0f', '10f', '24f'],
          'phase': 'during',
        }),
      );
      expect(
        code,
        allOf(
          contains('easings: [Ease.out, Ease.smooth]'),
          contains('at: [0.frames, 10.frames, 24.frames]'),
          contains('phase: AnimationPhase.during'),
        ),
      );
    });

    test('the tail trigger prints as trigger:, never at:', () {
      final code = printVideoSpecJson(
        _animated({
          'keyframes': [
            {'opacity': 0},
            {'opacity': 1},
          ],
          'duration': '24f',
          'at': 'sceneStart',
          'label': 'hop',
        }),
      );
      expect(
        code,
        allOf(
          contains('trigger: Trigger.sceneStart'),
          contains('duration: 24.frames'),
          contains("label: 'hop'"),
          isNot(contains('at: Trigger.sceneStart')),
        ),
      );
    });

    test('the printed form is valid Dart', () {
      final code = printVideoSpecJson(
        _animated({
          'keyframes': [
            {'opacity': 0, 'y': 0.6},
            {'opacity': 1, 'y': -0.15},
            {'y': 0},
          ],
          'easings': ['out', 'smooth'],
          'positions': ['0f', '10f', '24f'],
          'phase': 'during',
          'duration': '24f',
          'at': 'sceneStart',
        }),
      );
      final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
      expect(() => formatter.format(code), returnsNormally);
    });
  });
}
