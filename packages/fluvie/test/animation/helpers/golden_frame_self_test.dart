import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/rendering/runtime/frame_provider.dart';

import 'golden_frame.dart';

void main() {
  group('motionFrameGroup', () {
    testWidgets('builds one scenario per requested frame', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: motionFrameGroup(
            subject: () => const ColoredBox(color: Color(0xFF6C5CE7)),
            frames: const [0, 10, 20],
          ),
        ),
      );
      expect(find.byType(GoldenTestScenario), findsNWidgets(3));
    });

    testWidgets('each scenario delivers its own distinct frame to FrameProvider', (tester) async {
      final seen = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: motionFrameGroup(
            subject: () => Builder(
              builder: (context) {
                seen.add(FrameProvider.of(context).frame);
                return const ColoredBox(color: Color(0xFF6C5CE7));
              },
            ),
            frames: const [0, 10, 20],
          ),
        ),
      );
      expect(seen, [0, 10, 20]);
    });
  });
}
