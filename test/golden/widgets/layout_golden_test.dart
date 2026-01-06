@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

import '../../helpers/golden_helpers.dart';

void main() {
  group('Layout Widget Goldens', () {
    group('VCenter', () {
      testWidgets('centers child', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: SizedBox(
              width: 200,
              height: 200,
              child: ColoredBox(color: Colors.blue),
            ),
          ),
          name: 'widgets/layout/v_center',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('with width factor', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            widthFactor: 0.5,
            heightFactor: 0.5,
            child: ColoredBox(color: Colors.green),
          ),
          name: 'widgets/layout/v_center_factor',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('VColumn', () {
      testWidgets('default spacing', (tester) async {
        await expectGolden(
          tester,
          const VColumn(
            children: [
              SizedBox(
                width: 100,
                height: 50,
                child: ColoredBox(color: Colors.red),
              ),
              SizedBox(
                width: 100,
                height: 50,
                child: ColoredBox(color: Colors.green),
              ),
              SizedBox(
                width: 100,
                height: 50,
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
          name: 'widgets/layout/v_column_default',
          size: GoldenConfig.smallSize,
        );
      });

      testWidgets('with custom spacing', (tester) async {
        await expectGolden(
          tester,
          const VColumn(
            spacing: 32,
            children: [
              SizedBox(
                width: 100,
                height: 50,
                child: ColoredBox(color: Colors.red),
              ),
              SizedBox(
                width: 100,
                height: 50,
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
          name: 'widgets/layout/v_column_spacing',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('VRow', () {
      testWidgets('default spacing', (tester) async {
        await expectGolden(
          tester,
          const VRow(
            children: [
              SizedBox(
                width: 50,
                height: 100,
                child: ColoredBox(color: Colors.red),
              ),
              SizedBox(
                width: 50,
                height: 100,
                child: ColoredBox(color: Colors.green),
              ),
              SizedBox(
                width: 50,
                height: 100,
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
          name: 'widgets/layout/v_row_default',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('VStack', () {
      testWidgets('overlays children', (tester) async {
        await expectGolden(
          tester,
          VStack(
            children: [
              Container(
                width: 200,
                height: 200,
                color: Colors.red,
              ),
              Container(
                width: 150,
                height: 150,
                color: Colors.green.withValues(alpha: 0.8),
              ),
              Container(
                width: 100,
                height: 100,
                color: Colors.blue.withValues(alpha: 0.8),
              ),
            ],
          ),
          name: 'widgets/layout/v_stack_overlay',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('VPadding', () {
      testWidgets('applies padding', (tester) async {
        await expectGolden(
          tester,
          Container(
            color: Colors.grey.shade200,
            child: const VPadding(
              padding: EdgeInsets.all(32),
              child: SizedBox(
                width: 200,
                height: 200,
                child: ColoredBox(color: Colors.purple),
              ),
            ),
          ),
          name: 'widgets/layout/v_padding',
          size: GoldenConfig.smallSize,
        );
      });
    });

    group('VSizedBox', () {
      testWidgets('constrains size', (tester) async {
        await expectGolden(
          tester,
          const VCenter(
            child: VSizedBox(
              width: 300,
              height: 200,
              child: ColoredBox(color: Colors.orange),
            ),
          ),
          name: 'widgets/layout/v_sized_box',
          size: GoldenConfig.smallSize,
        );
      });
    });
  });
}
