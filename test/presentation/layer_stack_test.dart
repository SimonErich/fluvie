import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/presentation/layer_stack.dart';
import 'package:fluvie/src/presentation/layer.dart';

void main() {
  group('LayerStack', () {
    testWidgets('renders layers in order', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer(
                child: Container(key: const Key('layer1'), color: Colors.red),
              ),
              Layer(
                child: Container(key: const Key('layer2'), color: Colors.green),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('layer1')), findsOneWidget);
      expect(find.byKey(const Key('layer2')), findsOneWidget);
    });

    testWidgets('can be created with empty children', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LayerStack(children: [])),
      );

      expect(find.byType(LayerStack), findsOneWidget);
    });

    testWidgets('uses Stack for layout', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [Layer(child: Container(color: Colors.red))],
          ),
        ),
      );

      expect(find.byType(Stack), findsOneWidget);
    });

    testWidgets('respects alignment parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            alignment: Alignment.topLeft,
            children: [
              Layer(child: Container(color: Colors.red, width: 50, height: 50)),
            ],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.alignment, equals(Alignment.topLeft));
    });

    testWidgets('respects fit parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            fit: StackFit.expand,
            children: [Layer(child: Container(color: Colors.red))],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.fit, equals(StackFit.expand));
    });

    testWidgets('respects clipBehavior parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            clipBehavior: Clip.antiAlias,
            children: [Layer(child: Container(color: Colors.red))],
          ),
        ),
      );

      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.clipBehavior, equals(Clip.antiAlias));
    });
  });

  group('Layer', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer(
                child: Container(key: const Key('child'), color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('supports opacity property', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer(opacity: 0.5, child: Container(color: Colors.blue)),
            ],
          ),
        ),
      );

      expect(find.byType(Layer), findsOneWidget);
    });

    testWidgets('supports blendMode property', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer(
                blendMode: BlendMode.multiply,
                child: Container(color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      expect(find.byType(Layer), findsOneWidget);
    });

    testWidgets('supports enabled property', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer(
                enabled: false,
                child: Container(key: const Key('hidden'), color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      // Widget may still be in tree but not enabled
      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.enabled, isFalse);
    });
  });

  group('Layer.timed', () {
    testWidgets('creates layer with exact timing and no fade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.timed(
                startFrame: 30,
                endFrame: 120,
                child: Container(key: const Key('timed'), color: Colors.red),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.startFrame, equals(30));
      expect(layer.endFrame, equals(120));
      expect(layer.fadeInFrames, equals(0));
      expect(layer.fadeOutFrames, equals(0));
    });

    testWidgets('supports opacity parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.timed(
                startFrame: 0,
                endFrame: 100,
                opacity: 0.5,
                child: Container(color: Colors.red),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.opacity, equals(0.5));
    });

    testWidgets('supports id parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.timed(
                id: 'test-layer',
                startFrame: 0,
                endFrame: 100,
                child: Container(color: Colors.red),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.id, equals('test-layer'));
    });
  });

  group('Layer.faded', () {
    testWidgets('creates layer with symmetric fade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.faded(
                fadeFrames: 20,
                child: Container(key: const Key('faded'), color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.fadeInFrames, equals(20));
      expect(layer.fadeOutFrames, equals(20));
    });

    testWidgets('uses default 15 frame fade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [Layer.faded(child: Container(color: Colors.blue))],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.fadeInFrames, equals(15));
      expect(layer.fadeOutFrames, equals(15));
    });

    testWidgets('supports start and end frame', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.faded(
                startFrame: 30,
                endFrame: 150,
                child: Container(color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.startFrame, equals(30));
      expect(layer.endFrame, equals(150));
    });

    testWidgets('uses same curve for fade in and out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.faded(
                fadeCurve: Curves.linear,
                child: Container(color: Colors.blue),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.fadeInCurve, equals(Curves.linear));
      expect(layer.fadeOutCurve, equals(Curves.linear));
    });
  });

  group('Layer.fullDuration', () {
    testWidgets('creates layer visible for entire duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.fullDuration(
                child: Container(key: const Key('full'), color: Colors.green),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.startFrame, isNull);
      expect(layer.endFrame, isNull);
      expect(layer.fadeInFrames, equals(0));
      expect(layer.fadeOutFrames, equals(0));
    });

    testWidgets('supports opacity parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.fullDuration(
                opacity: 0.8,
                child: Container(color: Colors.green),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.opacity, equals(0.8));
    });

    testWidgets('supports id parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.fullDuration(
                id: 'watermark',
                child: Container(color: Colors.green),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.id, equals('watermark'));
    });
  });

  group('Layer.background', () {
    testWidgets('creates background layer with zIndex -1000', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [Layer.background(child: Container(color: Colors.black))],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.zIndex, equals(-1000));
    });

    testWidgets('uses srcOver blend mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [Layer.background(child: Container(color: Colors.black))],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.blendMode, equals(BlendMode.srcOver));
    });
  });

  group('Layer.overlay', () {
    testWidgets('creates overlay layer with zIndex 1000', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.overlay(
                child: Container(color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.zIndex, equals(1000));
    });

    testWidgets('supports custom blend mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LayerStack(
            children: [
              Layer.overlay(
                blendMode: BlendMode.screen,
                child: Container(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      final layer = tester.widget<Layer>(find.byType(Layer));
      expect(layer.blendMode, equals(BlendMode.screen));
    });
  });
}
