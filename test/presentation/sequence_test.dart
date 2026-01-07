import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/domain/render_config.dart';
import 'package:fluvie/src/presentation/sequence.dart';

void main() {
  group('Sequence', () {
    group('construction', () {
      test('creates with required parameters', () {
        const sequence = Sequence(
          startFrame: 0,
          durationInFrames: 100,
          child: SizedBox(),
        );

        expect(sequence.startFrame, 0);
        expect(sequence.durationInFrames, 100);
        expect(sequence.child, isA<SizedBox>());
      });

      test('accepts different startFrame values', () {
        const sequence = Sequence(
          startFrame: 50,
          durationInFrames: 100,
          child: SizedBox(),
        );

        expect(sequence.startFrame, 50);
      });

      test('accepts different durationInFrames values', () {
        const sequence = Sequence(
          startFrame: 0,
          durationInFrames: 500,
          child: SizedBox(),
        );

        expect(sequence.durationInFrames, 500);
      });
    });

    group('toSequenceConfig', () {
      test('creates SequenceConfig with correct values', () {
        const sequence = Sequence(
          startFrame: 30,
          durationInFrames: 150,
          child: SizedBox(),
        );

        final config = sequence.toSequenceConfig();

        expect(config, isA<SequenceConfig>());
        expect(config.startFrame, 30);
        expect(config.durationInFrames, 150);
      });

      test('handles zero startFrame', () {
        const sequence = Sequence(
          startFrame: 0,
          durationInFrames: 100,
          child: SizedBox(),
        );

        final config = sequence.toSequenceConfig();

        expect(config.startFrame, 0);
      });

      test('handles large values', () {
        const sequence = Sequence(
          startFrame: 10000,
          durationInFrames: 50000,
          child: SizedBox(),
        );

        final config = sequence.toSequenceConfig();

        expect(config.startFrame, 10000);
        expect(config.durationInFrames, 50000);
      });
    });

    group('toConfig', () {
      test('throws UnimplementedError', () {
        const sequence = Sequence(
          startFrame: 0,
          durationInFrames: 100,
          child: SizedBox(),
        );

        expect(() => sequence.toConfig(), throwsUnimplementedError);
      });
    });

    group('widget behavior', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Sequence(
              startFrame: 0,
              durationInFrames: 100,
              child: Text('Sequence Content'),
            ),
          ),
        );

        expect(find.text('Sequence Content'), findsOneWidget);
      });

      testWidgets('passes through child unchanged', (tester) async {
        const childKey = Key('child');

        await tester.pumpWidget(
          const MaterialApp(
            home: Sequence(
              startFrame: 0,
              durationInFrames: 100,
              child: SizedBox(key: childKey),
            ),
          ),
        );

        expect(find.byKey(childKey), findsOneWidget);
      });

      testWidgets('can be found by type', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Sequence(
              startFrame: 0,
              durationInFrames: 100,
              child: SizedBox(),
            ),
          ),
        );

        expect(find.byType(Sequence), findsOneWidget);
      });

      testWidgets('supports key parameter', (tester) async {
        const sequenceKey = Key('sequence');

        await tester.pumpWidget(
          const MaterialApp(
            home: Sequence(
              key: sequenceKey,
              startFrame: 0,
              durationInFrames: 100,
              child: SizedBox(),
            ),
          ),
        );

        expect(find.byKey(sequenceKey), findsOneWidget);
      });

      testWidgets('can be nested in other widgets', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Column(
              children: [
                Sequence(
                  startFrame: 0,
                  durationInFrames: 100,
                  child: Text('First'),
                ),
                Sequence(
                  startFrame: 100,
                  durationInFrames: 100,
                  child: Text('Second'),
                ),
              ],
            ),
          ),
        );

        expect(find.text('First'), findsOneWidget);
        expect(find.text('Second'), findsOneWidget);
        expect(find.byType(Sequence), findsNWidgets(2));
      });
    });

    group('edge cases', () {
      test('allows zero durationInFrames', () {
        const sequence = Sequence(
          startFrame: 0,
          durationInFrames: 0,
          child: SizedBox(),
        );

        final config = sequence.toSequenceConfig();
        expect(config.durationInFrames, 0);
      });

      testWidgets('handles complex child widgets', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Sequence(
              startFrame: 0,
              durationInFrames: 100,
              child: Container(
                color: Colors.red,
                child: const Column(
                  children: [
                    Text('Line 1'),
                    Text('Line 2'),
                    Text('Line 3'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Line 1'), findsOneWidget);
        expect(find.text('Line 2'), findsOneWidget);
        expect(find.text('Line 3'), findsOneWidget);
      });

      testWidgets('renders correctly at different frame times', (tester) async {
        // Sequence itself doesn't have timing logic - it just defines configuration
        // The actual timing is handled by the composition/layer system
        await tester.pumpWidget(
          const MaterialApp(
            home: Sequence(
              startFrame: 30,
              durationInFrames: 60,
              child: Text('Timed Content'),
            ),
          ),
        );

        // Content should always be rendered - sequence just stores config
        expect(find.text('Timed Content'), findsOneWidget);
      });
    });
  });

  group('SequenceConfig.base', () {
    test('creates config with required fields', () {
      const config = SequenceConfig.base(
        startFrame: 0,
        durationInFrames: 100,
      );

      expect(config.startFrame, 0);
      expect(config.durationInFrames, 100);
    });

    test('has correct type', () {
      const config = SequenceConfig.base(
        startFrame: 30,
        durationInFrames: 60,
      );

      expect(config.type, SequenceType.base);
    });

    test('serializes to JSON', () {
      const config = SequenceConfig.base(
        startFrame: 10,
        durationInFrames: 50,
      );

      final json = config.toJson();

      expect(json['startFrame'], 10);
      expect(json['durationInFrames'], 50);
    });
  });
}
