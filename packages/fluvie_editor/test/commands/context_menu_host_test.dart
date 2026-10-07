import 'package:flutter/gestures.dart' show PointerDeviceKind, kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:obers_ui/obers_ui.dart' show OiMenuDivider, OiMenuItem, OiThemeData, OiThemeScope;

/// Mounts the host over a plain [Overlay] — no OiApp, so the host takes its
/// fallback overlay path.
Future<void> _pumpBare(
  WidgetTester tester, {
  required List<OiMenuItem> items,
  bool enabled = true,
}) async {
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      builder: (context, _) => OiThemeScope(
        data: OiThemeData.dark(),
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => ContextMenuHost(
                label: 'Test menu',
                enabled: enabled,
                itemsAt: (_) => items,
                child: const ColoredBox(color: Color(0xFF222222), child: SizedBox.expand()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _rightClickAt(WidgetTester tester, Offset where) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.addPointer(location: where);
  addTearDown(gesture.removePointer);
  await gesture.down(where);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens through a plain Overlay when no OiOverlays exists', (tester) async {
    var tapped = false;
    await _pumpBare(
      tester,
      items: [
        OiMenuItem(label: 'Do it', shortcut: 'Ctrl+D', onTap: () => tapped = true),
        const OiMenuDivider(),
        const OiMenuItem(label: 'Checked', checked: true),
        const OiMenuItem(label: 'Unchecked', checked: false),
        const OiMenuItem(label: 'Held back', enabled: false),
      ],
    );
    await _rightClickAt(tester, const Offset(200, 200));
    expect(find.text('Do it'), findsOneWidget);
    expect(find.text('Ctrl+D'), findsOneWidget);
    expect(find.text('Held back'), findsOneWidget);
    await tester.tap(find.text('Do it'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(find.text('Do it'), findsNothing);
  });

  testWidgets('a click outside closes the fallback overlay', (tester) async {
    await _pumpBare(tester, items: const [OiMenuItem(label: 'Solo')]);
    await _rightClickAt(tester, const Offset(700, 60));
    expect(find.text('Solo'), findsOneWidget);
    await tester.tapAt(const Offset(60, 500));
    await tester.pumpAndSettle();
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('Escape closes the menu', (tester) async {
    await _pumpBare(tester, items: const [OiMenuItem(label: 'Solo')]);
    await _rightClickAt(tester, const Offset(200, 200));
    expect(find.text('Solo'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('a disabled host never opens', (tester) async {
    await _pumpBare(tester, items: const [OiMenuItem(label: 'Solo')], enabled: false);
    await _rightClickAt(tester, const Offset(200, 200));
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('empty items open nothing', (tester) async {
    await _pumpBare(tester, items: const []);
    await _rightClickAt(tester, const Offset(200, 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an open menu dies with its host', (tester) async {
    await _pumpBare(tester, items: const [OiMenuItem(label: 'Solo')]);
    await _rightClickAt(tester, const Offset(200, 200));
    expect(find.text('Solo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('a submenu drills down in place', (tester) async {
    var landed = false;
    await _pumpBare(
      tester,
      items: [
        OiMenuItem(
          label: 'More',
          children: [OiMenuItem(label: 'Deeper', onTap: () => landed = true)],
        ),
      ],
    );
    await _rightClickAt(tester, const Offset(200, 200));
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('More'), findsNothing);
    await tester.tap(find.text('Deeper'));
    await tester.pumpAndSettle();
    expect(landed, isTrue);
  });
}
