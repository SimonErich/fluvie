import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  await goldenTest(
    'golden harness renders a deterministic box',
    fileName: 'smoke_box',
    builder: () => GoldenTestGroup(
      children: [
        GoldenTestScenario(
          name: 'solid color',
          child: const SizedBox(
            width: 64,
            height: 64,
            child: ColoredBox(color: Color(0xFF6C5CE7)),
          ),
        ),
      ],
    ),
  );
}
