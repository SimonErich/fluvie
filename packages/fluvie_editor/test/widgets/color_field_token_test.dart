import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_editor/fluvie_editor.dart';
import 'package:fluvie_editor/src/widgets/spectrum_slider.dart' show SaturationValueArea;
import 'package:obers_ui/obers_ui.dart' show OiApp, OiThemeData;

const _accent = Color(0xFF6C5CE7);
const _muted = Color(0xFF9CA3AF);
const _recent = Color(0xFF123456);

final class _Picks {
  final List<Color> changes = [];
  final List<String> boundTokens = [];
  final List<Color> committed = [];
}

Future<_Picks> _pump(
  WidgetTester tester, {
  String? boundToken,
  List<Color> recents = const [],
}) async {
  final picks = _Picks();
  await tester.pumpWidget(
    OiApp(
      title: 'test',
      theme: OiThemeData.dark(),
      home: Center(
        child: SizedBox(
          width: 240,
          child: ColorField(
            label: 'Fill',
            color: _accent,
            boundToken: boundToken,
            tokens: const [
              NamedColor(name: 'accent', color: _accent),
              NamedColor(name: 'muted', color: _muted),
            ],
            recents: recents,
            onChanged: picks.changes.add,
            onTokenSelected: picks.boundTokens.add,
            onCommitted: picks.committed.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return picks;
}

void main() {
  testWidgets('a bound field shows the token chip', (tester) async {
    await _pump(tester, boundToken: 'accent');
    expect(find.text('accent'), findsOneWidget);
    expect(find.bySemanticsLabel('Unbind Fill'), findsOneWidget);
  });

  testWidgets('unbind writes the literal color once', (tester) async {
    final picks = await _pump(tester, boundToken: 'accent');
    await tester.tap(find.bySemanticsLabel('Unbind Fill'));
    await tester.pump();
    expect(picks.changes, const [_accent]);
    expect(picks.boundTokens, isEmpty);
  });

  testWidgets('the picker leads with theme, then recents, then spectrum', (tester) async {
    await _pump(tester, recents: const [_recent]);
    await tester.tap(find.bySemanticsLabel('Fill'));
    await tester.pumpAndSettle();
    final themeY = tester.getTopLeft(find.bySemanticsLabel('Token accent')).dy;
    final recentY = tester.getTopLeft(find.bySemanticsLabel('Recent color 1')).dy;
    final spectrumY = tester.getTopLeft(find.byType(SaturationValueArea)).dy;
    expect(themeY, lessThan(recentY));
    expect(recentY, lessThan(spectrumY));
  });

  testWidgets('tapping a theme swatch binds its token and closes', (tester) async {
    final picks = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Fill'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Token muted'));
    await tester.pumpAndSettle();
    expect(picks.boundTokens, ['muted']);
    expect(picks.changes, isEmpty);
    expect(picks.committed, isEmpty, reason: 'a bind is not a literal pick');
    expect(find.byType(SaturationValueArea), findsNothing, reason: 'the dialog closed');
  });

  testWidgets('tapping a recent picks that color', (tester) async {
    final picks = await _pump(tester, recents: const [_recent]);
    await tester.tap(find.bySemanticsLabel('Fill'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Recent color 1'));
    await tester.pump();
    expect(picks.changes, const [_recent]);
  });

  testWidgets('closing after a pick commits once for the recents row', (tester) async {
    final picks = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Fill'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picks.committed, const [Color(0xFFFF0000)]);
  });

  testWidgets('closing without a pick commits nothing', (tester) async {
    final picks = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Fill'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picks.committed, isEmpty);
  });
}
