import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/errors/fluvie_spec_error.dart';
import 'package:fluvie/src/core/placement.dart';
import 'package:fluvie/src/elements/placed.dart';
import 'package:fluvie/src/rendering/runtime/render_controller.dart';
import 'package:fluvie/src/rendering/runtime/render_controller_scope.dart';
import 'package:fluvie/src/rendering/runtime/render_mode.dart';
import 'package:fluvie/src/rendering/runtime/render_mode_context.dart';
import 'package:fluvie/src/serialization/codecs/placement_codec.dart';
import 'package:fluvie/src/serialization/scene_spec.dart';
import 'package:fluvie/src/serialization/spec_validation.dart';
import 'package:fluvie/src/serialization/video_spec.dart';

Map<String, Object?> _positionedSpec() => {
  'fluvieSpec': 1,
  'size': {'width': 320, 'height': 180},
  'fps': 30,
  'scenes': [
    {
      'duration': '60f',
      'layout': 'canvas',
      'children': [
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'placed',
          'transform': {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 0.25},
        },
        {
          'type': 'Text',
          'text': 'stacked',
        },
      ],
    },
  ],
};

void main() {
  group('Placement', () {
    test('resolves a sized rect from fractions, anchored at center', () {
      const placement = Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.25);
      final rect = placement.rectFor(const Size(320, 180));
      expect(rect, const Rect.fromLTWH(0, 67.5, 160, 45));
    });

    test('an intrinsic placement needs the child size', () {
      const placement = Placement(x: 0.5, y: 0.5);
      expect(placement.rectFor(const Size(320, 180)), isNull);
      final rect = placement.rectFor(const Size(320, 180), childSize: const Size(40, 20));
      expect(rect, const Rect.fromLTWH(140, 80, 40, 20));
    });

    test('a non-center anchor moves the reference point', () {
      const placement = Placement(
        x: 0,
        y: 0,
        width: 0.5,
        height: 0.5,
        anchor: Alignment.topLeft,
      );
      expect(placement.rectFor(const Size(100, 100)), const Rect.fromLTWH(0, 0, 50, 50));
    });

    test('value equality holds', () {
      expect(
        const Placement(x: 0.1, y: 0.2, rotation: 45),
        const Placement(x: 0.1, y: 0.2, rotation: 45),
      );
    });
  });

  group('placement codec', () {
    test('round-trips every field', () {
      final json = {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.4, 'rotation': 15, 'anchor': 'topLeft'};
      final placement = decodePlacement(json);
      expect(encodePlacement(placement), {
        'x': 0.1,
        'y': 0.2,
        'w': 0.3,
        'h': 0.4,
        'rotation': 15.0,
        'anchor': 'topLeft',
      });
    });

    test('defaults: no size, no rotation, center anchor', () {
      final placement = decodePlacement({'x': 0.5, 'y': 0.5});
      expect(placement.width, isNull);
      expect(placement.rotation, 0);
      expect(placement.anchor, Alignment.center);
      expect(encodePlacement(placement), {'x': 0.5, 'y': 0.5});
    });

    test('rejects a transform without x and y', () {
      expect(
        () => decodePlacement({'x': 0.5}),
        throwsA(isA<FluvieSpecError>()),
      );
    });

    test('rejects an unknown anchor name', () {
      expect(
        () => decodePlacement({'x': 0, 'y': 0, 'anchor': 'noSuchCorner'}),
        throwsA(isA<FluvieSpecError>()),
      );
    });
  });

  group('spec round-trip', () {
    test('id and transform survive fromJson and toJson', () {
      final spec = VideoSpec.fromJson(_positionedSpec());
      final element = spec.scenes.first.children.first;
      expect(element.id, 'el-title');
      expect(element.placement, const Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.25));
      final json = spec.toJson();
      final scenes = json['scenes']! as List;
      final children = (scenes.first as Map)['children'] as List;
      expect((children.first as Map)['id'], 'el-title');
      expect((children.first as Map)['transform'], {'x': 0.25, 'y': 0.5, 'w': 0.5, 'h': 0.25});
      expect((children.last as Map).containsKey('transform'), isFalse);
    });

    test('scene layout parses, defaults to stack, and round-trips', () {
      final spec = VideoSpec.fromJson(_positionedSpec());
      expect(spec.scenes.first.layout, SceneLayout.canvas);
      final json = spec.toJson();
      expect(((json['scenes']! as List).first as Map)['layout'], 'canvas');

      final plain = VideoSpec.fromJson({
        'scenes': [
          {'duration': '30f', 'children': <Object?>[]},
        ],
      });
      expect(plain.scenes.first.layout, SceneLayout.stack);
      expect(
        ((plain.toJson()['scenes']! as List).first as Map).containsKey('layout'),
        isFalse,
      );
    });

    test('an unknown layout value is rejected with its path', () {
      expect(
        () => VideoSpec.fromJson({
          'scenes': [
            {'duration': '30f', 'layout': 'freeform', 'children': <Object?>[]},
          ],
        }),
        throwsA(
          isA<FluvieSpecError>().having((e) => e.message, 'message', contains('layout')),
        ),
      );
    });

    test('digest changes when a transform changes', () {
      final a = VideoSpec.fromJson(_positionedSpec());
      final moved = _positionedSpec();
      final scene = (moved['scenes']! as List).first as Map<String, Object?>;
      final child = (scene['children']! as List).first as Map<String, Object?>;
      child['transform'] = {'x': 0.75, 'y': 0.5, 'w': 0.5, 'h': 0.25};
      final b = VideoSpec.fromJson(moved);
      expect(a.digest(), isNot(b.digest()));
    });
  });

  group('validation', () {
    test('id, transform, and layout are known keys', () {
      expect(unknownSpecProps(_positionedSpec()), isEmpty);
    });

    test('a typo inside transform is reported', () {
      final json = _positionedSpec();
      final scene = (json['scenes']! as List).first as Map<String, Object?>;
      final child = (scene['children']! as List).first as Map<String, Object?>;
      child['transform'] = {'x': 0.1, 'y': 0.1, 'rotaton': 5};
      final warnings = unknownSpecProps(json);
      expect(warnings, hasLength(1));
      expect(warnings.single.toString(), contains('rotaton'));
    });
  });

  group('Placed rendering', () {
    testWidgets('a sized placement lands the child on its rect', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: Placed(
                placement: Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.25),
                child: ColoredBox(color: Color(0xFF123456)),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byType(ColoredBox));
      final canvasTopLeft = tester.getTopLeft(find.byType(Placed));
      expect(rect.shift(-canvasTopLeft), const Rect.fromLTWH(0, 67.5, 160, 45));
    });

    testWidgets('an intrinsic placement centers the child on the point', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 320,
              height: 180,
              child: Placed(
                placement: Placement(x: 0.5, y: 0.25),
                child: SizedBox(width: 40, height: 20),
              ),
            ),
          ),
        ),
      );
      final rect = tester.getRect(
        find.descendant(of: find.byType(Placed), matching: find.byType(SizedBox)).last,
      );
      final canvasTopLeft = tester.getTopLeft(find.byType(Placed));
      expect(rect.shift(-canvasTopLeft), const Rect.fromLTWH(140, 35, 40, 20));
    });

    testWidgets('rotation wraps the child in a rotation transform', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 100,
            height: 100,
            child: Placed(
              placement: Placement(x: 0.5, y: 0.5, width: 0.5, height: 0.5, rotation: 90),
              child: SizedBox(),
            ),
          ),
        ),
      );
      expect(
        find.descendant(of: find.byType(Placed), matching: find.byType(Transform)),
        findsOneWidget,
      );
    });
  });

  group('buildElement wiring', () {
    testWidgets('a transformed element mounts inside Placed; a plain one does not', (
      tester,
    ) async {
      final video = VideoSpec.fromJson(_positionedSpec()).build();
      await tester.pumpWidget(_harness(video, RenderController()));
      await tester.pump();
      expect(find.byType(Placed), findsOneWidget);
      expect(
        find.ancestor(of: find.text('placed'), matching: find.byType(Placed)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: find.text('stacked'), matching: find.byType(Placed)),
        findsNothing,
      );
    });
  });
}

/// Mounts a Video on the same scopes the render pipeline provides.
Widget _harness(Video video, RenderController controller) => RenderModeContext(
  mode: RenderMode.capture,
  child: RenderControllerScope(
    controller: controller,
    child: Directionality(textDirection: TextDirection.ltr, child: video),
  ),
);
