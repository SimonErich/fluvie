import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/animation/stagger/multi_child_rebuilder.dart';

Widget _box({Key? key, double size = 20}) => SizedBox(
  key: key,
  width: size,
  height: size,
  child: const ColoredBox(color: Color(0xFF123456)),
);

Widget _mark(int index, Widget child) =>
    KeyedSubtree(key: ValueKey('wrapped-$index'), child: child);

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 100, height: 100, child: child)),
);

void main() {
  group('rebuildWithWrappedChildren — Flex (Row/Column)', () {
    testWidgets('Row layout properties survive the rebuild', (tester) async {
      final row = Row(
        key: const Key('container'),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        verticalDirection: VerticalDirection.up,
        spacing: 8,
        children: [_box(), _box()],
      );
      final rebuilt = rebuildWithWrappedChildren(row, _mark);
      expect(rebuilt, isNotNull);
      await tester.pumpWidget(_host(rebuilt!));
      final flex = tester.widget<Flex>(find.byKey(const Key('container')));
      expect(flex.direction, Axis.horizontal);
      expect(flex.mainAxisAlignment, MainAxisAlignment.spaceBetween);
      expect(flex.mainAxisSize, MainAxisSize.min);
      expect(flex.crossAxisAlignment, CrossAxisAlignment.end);
      expect(flex.verticalDirection, VerticalDirection.up);
      expect(flex.spacing, 8);
      expect(find.byKey(const ValueKey('wrapped-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('wrapped-1')), findsOneWidget);
    });

    testWidgets('Column keeps its vertical direction', (tester) async {
      final rebuilt = rebuildWithWrappedChildren(Column(children: [_box(), _box()]), _mark);
      await tester.pumpWidget(_host(rebuilt!));
      expect(tester.widget<Flex>(find.byType(Flex)).direction, Axis.vertical);
    });

    testWidgets('an Expanded child is wrapped INSIDE Expanded — flex layout unchanged', (
      tester,
    ) async {
      const inner = Key('expanded child');
      Widget row(Widget Function(int, Widget) wrap) => rebuildWithWrappedChildren(
        Row(
          children: [
            Expanded(flex: 2, child: _box(key: inner)),
            _box(),
          ],
        ),
        wrap,
      )!;
      await tester.pumpWidget(_host(row((_, child) => child)));
      final unwrapped = tester.getSize(find.byKey(inner));

      await tester.pumpWidget(_host(row(_mark)));
      expect(tester.takeException(), isNull);
      final expanded = tester.widget<Expanded>(find.byType(Expanded));
      expect(expanded.flex, 2);
      expect(
        find.descendant(
          of: find.byType(Expanded),
          matching: find.byKey(const ValueKey('wrapped-0')),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byKey(inner)), unwrapped);
    });

    testWidgets('a loose Flexible child keeps its fit and flex', (tester) async {
      final rebuilt = rebuildWithWrappedChildren(
        Row(
          children: [
            Flexible(flex: 3, child: _box()),
            _box(),
          ],
        ),
        _mark,
      );
      await tester.pumpWidget(_host(rebuilt!));
      expect(tester.takeException(), isNull);
      final flexible = tester.widget<Flexible>(find.byType(Flexible));
      expect(flexible.flex, 3);
      expect(flexible.fit, FlexFit.loose);
      expect(
        find.descendant(
          of: find.byType(Flexible),
          matching: find.byKey(const ValueKey('wrapped-0')),
        ),
        findsOneWidget,
      );
    });
  });

  group('rebuildWithWrappedChildren — Wrap', () {
    testWidgets('spacing, runSpacing, and alignment survive', (tester) async {
      final rebuilt = rebuildWithWrappedChildren(
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.spaceAround,
          runAlignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [_box(), _box(), _box()],
        ),
        _mark,
      );
      expect(rebuilt, isNotNull);
      await tester.pumpWidget(_host(rebuilt!));
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 6);
      expect(wrap.runSpacing, 4);
      expect(wrap.alignment, WrapAlignment.spaceAround);
      expect(wrap.runAlignment, WrapAlignment.end);
      expect(wrap.crossAxisAlignment, WrapCrossAlignment.center);
      expect(find.byKey(const ValueKey('wrapped-2')), findsOneWidget);
    });
  });

  group('rebuildWithWrappedChildren — Stack', () {
    testWidgets('alignment, fit, and clipBehavior survive', (tester) async {
      final rebuilt = rebuildWithWrappedChildren(
        Stack(
          alignment: Alignment.bottomRight,
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [_box(), _box()],
        ),
        _mark,
      );
      await tester.pumpWidget(_host(rebuilt!));
      final stack = tester.widget<Stack>(find.byType(Stack));
      expect(stack.alignment, Alignment.bottomRight);
      expect(stack.fit, StackFit.expand);
      expect(stack.clipBehavior, Clip.none);
    });

    testWidgets('a Positioned child is wrapped INSIDE Positioned — geometry unchanged', (
      tester,
    ) async {
      const inner = Key('positioned child');
      final rebuilt = rebuildWithWrappedChildren(
        Stack(
          children: [
            Positioned(left: 5, top: 7, width: 30, height: 10, child: _box(key: inner)),
            _box(),
          ],
        ),
        _mark,
      );
      await tester.pumpWidget(_host(rebuilt!));
      expect(tester.takeException(), isNull);
      final positioned = tester.widget<Positioned>(find.byType(Positioned));
      expect(positioned.left, 5);
      expect(positioned.top, 7);
      expect(positioned.width, 30);
      expect(positioned.height, 10);
      expect(
        find.descendant(
          of: find.byType(Positioned),
          matching: find.byKey(const ValueKey('wrapped-0')),
        ),
        findsOneWidget,
      );
      final stackTopLeft = tester.getTopLeft(find.byType(Stack));
      expect(tester.getTopLeft(find.byKey(inner)), stackTopLeft + const Offset(5, 7));
      expect(tester.getSize(find.byKey(inner)), const Size(30, 10));
    });
  });

  group('rebuildWithWrappedChildren — the single-child sentinel', () {
    test('an unsupported container returns null so the caller treats it as single-child', () {
      expect(
        rebuildWithWrappedChildren(Padding(padding: EdgeInsets.zero, child: _box()), _mark),
        isNull,
      );
      expect(rebuildWithWrappedChildren(_box(), _mark), isNull);
    });
  });

  group('wrappableChildrenOf', () {
    test('returns the direct children of supported containers, in order', () {
      final a = _box();
      final b = _box();
      expect(wrappableChildrenOf(Row(children: [a, b])), [a, b]);
      expect(wrappableChildrenOf(Wrap(children: [a])), [a]);
      expect(wrappableChildrenOf(Stack(children: [b, a])), [b, a]);
    });

    test('returns null for anything else', () {
      expect(wrappableChildrenOf(_box()), isNull);
      expect(wrappableChildrenOf(Center(child: _box())), isNull);
    });
  });
}
