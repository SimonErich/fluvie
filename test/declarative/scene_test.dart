import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/declarative/core/scene.dart';
import 'package:fluvie/src/declarative/background/background.dart';
import 'package:fluvie/src/declarative/core/scene_transition.dart';

void main() {
  group('Scene', () {
    testWidgets('creates scene with required durationInFrames', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene(
            durationInFrames: 120,
            children: [Container(key: const Key('child'), color: Colors.blue)],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.durationInFrames, equals(120));
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('supports background property', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene(
            durationInFrames: 90,
            background: Background.solid(Colors.red),
            children: [],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.background, isNotNull);
    });

    testWidgets('supports fade properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene(
            durationInFrames: 90,
            fadeInFrames: 15,
            fadeOutFrames: 20,
            fadeInCurve: Curves.easeIn,
            fadeOutCurve: Curves.easeOut,
            children: [],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.fadeInFrames, equals(15));
      expect(scene.fadeOutFrames, equals(20));
      expect(scene.fadeInCurve, equals(Curves.easeIn));
      expect(scene.fadeOutCurve, equals(Curves.easeOut));
    });

    testWidgets('supports transition properties', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene(
            durationInFrames: 90,
            transitionIn: SceneTransition.crossFade(durationInFrames: 15),
            transitionOut: SceneTransition.crossFade(
              durationInFrames: 10,
            ),
            children: [],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.transitionIn, isNotNull);
      expect(scene.transitionOut, isNotNull);
    });
  });

  group('Scene.solid', () {
    testWidgets('creates scene with solid color background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.solid(
            durationInFrames: 120,
            color: Colors.black,
            children: [Container(key: const Key('child'))],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.durationInFrames, equals(120));
      expect(scene.background, isA<SolidBackground>());
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('passes through fade properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.solid(
            durationInFrames: 120,
            color: Colors.blue,
            fadeInFrames: 10,
            fadeOutFrames: 15,
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.fadeInFrames, equals(10));
      expect(scene.fadeOutFrames, equals(15));
    });

    testWidgets('passes through transition properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.solid(
            durationInFrames: 120,
            color: Colors.blue,
            transitionIn: const SceneTransition.crossFade(durationInFrames: 20),
            transitionOut: const SceneTransition.crossFade(
              durationInFrames: 20,
            ),
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.transitionIn, isNotNull);
      expect(scene.transitionOut, isNotNull);
    });
  });

  group('Scene.gradient', () {
    testWidgets('creates scene with gradient background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.gradient(
            durationInFrames: 120,
            colors: const {0: Colors.blue, 120: Colors.purple},
            children: [Container(key: const Key('child'))],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.durationInFrames, equals(120));
      expect(scene.background, isA<GradientBackground>());
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('supports gradient type parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.gradient(
            durationInFrames: 120,
            colors: const {0: Colors.red, 120: Colors.orange},
            type: GradientType.radial,
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      final bg = scene.background as GradientBackground;
      expect(bg.type, equals(GradientType.radial));
    });

    testWidgets('supports alignment parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scene.gradient(
            durationInFrames: 120,
            colors: const {0: Colors.red, 120: Colors.orange},
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      final bg = scene.background as GradientBackground;
      expect(bg.begin, equals(Alignment.centerLeft));
      expect(bg.end, equals(Alignment.centerRight));
    });
  });

  group('Scene.crossFade', () {
    testWidgets('creates scene with crossfade transitions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene.crossFade(
            durationInFrames: 120,
            transitionFrames: 20,
            children: [],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.durationInFrames, equals(120));
      expect(scene.transitionIn, isNotNull);
      expect(scene.transitionOut, isNotNull);
      expect(scene.fadeInFrames, equals(20));
      expect(scene.fadeOutFrames, equals(20));
    });

    testWidgets('supports optional background', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene.crossFade(
            durationInFrames: 120,
            background: Background.solid(Colors.black),
            children: [],
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.background, isNotNull);
    });

    testWidgets('uses default 15 frame transitions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene.crossFade(durationInFrames: 120, children: []),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.fadeInFrames, equals(15));
      expect(scene.fadeOutFrames, equals(15));
    });
  });

  group('Scene.empty', () {
    testWidgets('creates empty scene with no children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scene.empty(durationInFrames: 30)),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.durationInFrames, equals(30));
      expect(scene.children, isEmpty);
      expect(scene.background, isNull);
    });

    testWidgets('has no fade by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scene.empty(durationInFrames: 30)),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.fadeInFrames, equals(0));
      expect(scene.fadeOutFrames, equals(0));
    });

    testWidgets('supports optional transitions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scene.empty(
            durationInFrames: 30,
            transitionIn: SceneTransition.crossFade(durationInFrames: 10),
            transitionOut: SceneTransition.crossFade(durationInFrames: 10),
          ),
        ),
      );

      final scene = tester.widget<Scene>(find.byType(Scene));
      expect(scene.transitionIn, isNotNull);
      expect(scene.transitionOut, isNotNull);
    });
  });

  group('SceneContext', () {
    testWidgets('provides scene timing information to descendants', (
      tester,
    ) async {
      SceneContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: SceneContext(
            sceneStartFrame: 100,
            sceneDurationInFrames: 200,
            child: Builder(
              builder: (context) {
                capturedContext = SceneContext.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(capturedContext, isNotNull);
      expect(capturedContext!.sceneStartFrame, equals(100));
      expect(capturedContext!.sceneDurationInFrames, equals(200));
    });

    testWidgets('returns null when no SceneContext ancestor exists', (
      tester,
    ) async {
      SceneContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = SceneContext.of(context);
              return Container();
            },
          ),
        ),
      );

      expect(capturedContext, isNull);
    });

    testWidgets('notifies when sceneStartFrame changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SceneContext(
            sceneStartFrame: 0,
            sceneDurationInFrames: 100,
            child: Builder(
              builder: (context) {
                SceneContext.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      await tester.pumpWidget(
        MaterialApp(
          home: SceneContext(
            sceneStartFrame: 50, // Changed
            sceneDurationInFrames: 100,
            child: Builder(
              builder: (context) {
                SceneContext.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(2));
    });

    testWidgets('notifies when sceneDurationInFrames changes', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SceneContext(
            sceneStartFrame: 0,
            sceneDurationInFrames: 100,
            child: Builder(
              builder: (context) {
                SceneContext.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      await tester.pumpWidget(
        MaterialApp(
          home: SceneContext(
            sceneStartFrame: 0,
            sceneDurationInFrames: 200, // Changed
            child: Builder(
              builder: (context) {
                SceneContext.of(context);
                buildCount++;
                return Container();
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(2));
    });
  });
}
