import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/runtime/gradient_shift_scope.dart';

const _blue = Color(0xFF0000FF);
const _green = Color(0xFF00FF00);
const _red = Color(0xFFFF0000);

void main() {
  group('GradientShiftScope (WI-19, D10)', () {
    testWidgets('maybeOf returns the enclosing scope with its values', (tester) async {
      GradientShiftScope? seen;
      await tester.pumpWidget(
        GradientShiftScope(
          progress: 0.25,
          colors: const [_blue, _green],
          child: Builder(
            builder: (context) {
              seen = GradientShiftScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.progress, 0.25);
      expect(seen!.colors, const [_blue, _green]);
    });

    testWidgets('maybeOf returns null outside any scope', (tester) async {
      GradientShiftScope? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = GradientShiftScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, isNull);
    });

    testWidgets('the nearest scope wins under nesting', (tester) async {
      GradientShiftScope? seen;
      await tester.pumpWidget(
        GradientShiftScope(
          progress: 0.2,
          colors: const [_red],
          child: GradientShiftScope(
            progress: 0.8,
            colors: const [_blue],
            child: Builder(
              builder: (context) {
                seen = GradientShiftScope.maybeOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen!.progress, 0.8);
      expect(seen!.colors, const [_blue]);
    });

    testWidgets('notifies dependents only when progress or colors change', (tester) async {
      var builds = 0;
      final probe = Builder(
        builder: (context) {
          GradientShiftScope.maybeOf(context);
          builds++;
          return const SizedBox.shrink();
        },
      );
      Future<void> mount(double progress, List<Color> colors) => tester.pumpWidget(
        GradientShiftScope(progress: progress, colors: colors, child: probe),
      );

      await mount(0, const [_blue, _green]);
      expect(builds, 1);
      // Equal values (a fresh but element-equal list) must not notify.
      await mount(0, [_blue, _green]);
      expect(builds, 1);
      await mount(0.5, const [_blue, _green]);
      expect(builds, 2);
      await mount(0.5, const [_red, _green]);
      expect(builds, 3);
    });
  });
}
