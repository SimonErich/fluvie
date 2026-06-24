@Tags(['golden'])
library;

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitten_kit/kitten_kit.dart';

Future<void> main() async {
  await goldenTest(
    'kitten visuals render deterministically',
    fileName: 'kitten_visuals',
    builder: () => GoldenTestGroup(
      columns: 3,
      children: [
        GoldenTestScenario(
          name: 'tabby face',
          child: const SizedBox(width: 200, height: 200, child: KittenFace(size: 200)),
        ),
        GoldenTestScenario(
          name: 'pink face',
          child: const SizedBox(
            width: 200,
            height: 200,
            child: KittenFace(size: 200, fur: KittenColors.mitten),
          ),
        ),
        GoldenTestScenario(
          name: 'paw print',
          child: const SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(painter: PawPrintPainter()),
          ),
        ),
      ],
    ),
  );
}
