import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart' show Placed, PlacedOverrides, Placement;
import 'package:fluvie/src/serialization/anchor_table.dart';
import 'package:fluvie/src/serialization/element_spec.dart';

/// A child that logs its builds, so the tests can pin exactly which elements
/// an override update rebuilds.
final class _BuildProbe extends StatelessWidget {
  const _BuildProbe(this.log, this.name);

  final List<String> log;
  final String name;

  @override
  Widget build(BuildContext context) {
    log.add(name);
    return const SizedBox.expand();
  }
}

Finder _probe(String name) =>
    find.byWidgetPredicate((widget) => widget is _BuildProbe && widget.name == name);

/// The composition under edit. Built once per test and reused across pumps,
/// exactly like an editor holds one derived subtree while a drag updates the
/// overrides around it.
Widget _scene(List<String> log) => Stack(
  children: [
    Placed(
      id: 'el-a',
      placement: const Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.5),
      child: _BuildProbe(log, 'a'),
    ),
    Placed(
      id: 'el-b',
      placement: const Placement(x: 0.75, y: 0.5, width: 0.25, height: 0.5),
      child: _BuildProbe(log, 'b'),
    ),
    Placed(
      // No id: an anonymous element can never be overridden.
      placement: const Placement(x: 0.5, y: 0.5, width: 0.1, height: 0.1),
      child: _BuildProbe(log, 'anon'),
    ),
  ],
);

Widget _host(Map<String, Placement> overrides, Widget scene) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: SizedBox(
      width: 200,
      height: 100,
      child: PlacedOverrides(overrides: overrides, child: scene),
    ),
  ),
);

void main() {
  testWidgets('without overrides every element sits on its authored placement', (tester) async {
    await tester.pumpWidget(_host(const {}, _scene([])));
    final origin = tester.getTopLeft(_probe('anon')) - const Offset(90, 45);
    expect(tester.getRect(_probe('a')), const Rect.fromLTWH(0, 25, 100, 50).shift(origin));
    expect(tester.getRect(_probe('b')), const Rect.fromLTWH(125, 25, 50, 50).shift(origin));
  });

  testWidgets('an override re-places its element and only its element', (tester) async {
    final log = <String>[];
    final scene = _scene(log);
    await tester.pumpWidget(_host(const {}, scene));
    final origin = tester.getTopLeft(_probe('anon')) - const Offset(90, 45);
    log.clear();

    await tester.pumpWidget(
      _host(const {'el-a': Placement(x: 0.5, y: 0.5, width: 0.5, height: 0.5)}, scene),
    );
    expect(tester.getRect(_probe('a')), const Rect.fromLTWH(50, 25, 100, 50).shift(origin));
    expect(tester.getRect(_probe('b')), const Rect.fromLTWH(125, 25, 50, 50).shift(origin));
    // The fast path: the dragged element rebuilds, untouched ones do not.
    expect(log, isNot(contains('b')));
    expect(log, isNot(contains('anon')));

    // Clearing the override lands the element back on its authored placement.
    log.clear();
    await tester.pumpWidget(_host(const {}, scene));
    expect(tester.getRect(_probe('a')), const Rect.fromLTWH(0, 25, 100, 50).shift(origin));
    expect(log, isNot(contains('b')));
  });

  testWidgets('an element without an id ignores every override', (tester) async {
    final scene = _scene([]);
    await tester.pumpWidget(_host(const {}, scene));
    final before = tester.getRect(_probe('anon'));
    await tester.pumpWidget(
      _host(const {'el-anon': Placement(x: 0.1, y: 0.1, width: 0.1, height: 0.1)}, scene),
    );
    expect(tester.getRect(_probe('anon')), before);
  });

  testWidgets('an override outside any scope changes nothing', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 100,
            child: Placed(
              id: 'el-a',
              placement: const Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.5),
              child: _BuildProbe(log, 'a'),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(_probe('a')), const Size(100, 50));
  });

  testWidgets('buildElement hands the spec id to Placed', (tester) async {
    final element = ElementSpec.fromJson(const {
      'id': 'el-7',
      'type': 'Box',
      'color': '#FF0000',
      'transform': {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
    }, AnchorTable());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(width: 100, height: 100, child: element.build(AnchorTable())),
      ),
    );
    expect(tester.widget<Placed>(find.byType(Placed)).id, 'el-7');
  });

  testWidgets('an override also drives the rotation', (tester) async {
    await tester.pumpWidget(
      _host(
        const {'el-a': Placement(x: 0.25, y: 0.5, width: 0.5, height: 0.5, rotation: 90)},
        _scene([]),
      ),
    );
    // A rotated child still lays out on the unrotated rect; the turn happens
    // visually. The Transform widget between Placed and the probe proves the
    // override's rotation reached the render.
    final transform = find.ancestor(of: _probe('a'), matching: find.byType(Transform));
    expect(transform, findsOneWidget);
  });
}
