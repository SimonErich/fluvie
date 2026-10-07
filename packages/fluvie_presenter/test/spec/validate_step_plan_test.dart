import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

VideoSpec _spec(List<Object?> scenes) => VideoSpec.fromJson({
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'scenes': scenes,
});

Map<String, Object?> _scene({required List<Object?> children, Object? steps}) => {
  'duration': '4s',
  'children': children,
  'steps': ?steps,
};

/// A scene whose stepped element carries [trigger] — invalid inside a Stop
/// when the trigger crosses elements or rides the beat grid.
Map<String, Object?> _sceneWithSteppedTrigger(Object trigger) => _scene(
  children: [
    {
      'id': 'el-base',
      'type': 'Text',
      'text': 'Base',
      'anchor': 'intro',
      'animate': [
        {'preset': 'fadeIn', 'duration': '30f'},
      ],
    },
    {
      'id': 'el-late',
      'type': 'Text',
      'text': 'Late',
      'animate': [
        {'preset': 'fadeIn', 'at': trigger},
      ],
    },
  ],
  steps: const [
    {
      'elements': ['el-late'],
    },
  ],
);

void main() {
  test('a clean stepped deck validates to an empty list', () {
    final errors = validateStepPlan(
      _spec([
        _scene(
          children: const [
            {'id': 'el-a', 'type': 'Text', 'text': 'A'},
            {
              'id': 'el-b',
              'type': 'Text',
              'text': 'B',
              'animate': [
                {'preset': 'slideFadeIn', 'duration': '20f'},
              ],
            },
          ],
          steps: const [
            {
              'elements': ['el-b'],
            },
          ],
        ),
      ]),
    );
    expect(errors, isEmpty);
  });

  test('a cross-element trigger on a stepped element is reported', () {
    final errors = validateStepPlan(
      _spec([
        _sceneWithSteppedTrigger(const {'kind': 'whenEnds', 'anchor': 'intro'}),
      ]),
    );
    expect(errors, hasLength(1));
    expect(errors.single.message, contains('resolve locally'));
  });

  test('a beat trigger on a stepped element is reported', () {
    final errors = validateStepPlan(
      _spec([
        _sceneWithSteppedTrigger(const {'kind': 'beat', 'every': 1}),
      ]),
    );
    expect(errors, hasLength(1));
  });

  test('two broken scenes surface together, one error each', () {
    final errors = validateStepPlan(
      _spec([
        _sceneWithSteppedTrigger(const {'kind': 'whenEnds', 'anchor': 'intro'}),
        _sceneWithSteppedTrigger(const {'kind': 'beat', 'every': 1}),
      ]),
    );
    expect(errors, hasLength(2));
  });

  test('reference problems collect across steps and scenes without compiling', () {
    final errors = validateStepPlan(
      _spec([
        _scene(
          children: const [
            {'id': 'el-a', 'type': 'Text', 'text': 'A'},
          ],
          steps: const [
            {
              'elements': ['el-ghost'],
            },
            {
              'elements': ['el-a'],
            },
            {
              'elements': ['el-a'],
            },
          ],
        ),
        _scene(
          children: const [
            {'id': 'el-x', 'type': 'Text', 'text': 'X'},
          ],
          steps: const [
            {
              'elements': ['el-y'],
            },
          ],
        ),
      ]),
    );
    expect(errors, hasLength(3));
    expect(errors[0].message, contains('"el-ghost"'));
    expect(errors[1].message, contains('at most one step'));
    expect(errors[2].message, contains('"el-y"'));
  });

  test('a valid deck with reference-clean steps never throws, only returns', () {
    expect(
      () => validateStepPlan(
        _spec([
          _sceneWithSteppedTrigger(const {'kind': 'beat', 'every': 1}),
        ]),
      ),
      returnsNormally,
    );
  });
}
