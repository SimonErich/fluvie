import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/theme/widgets/gradient_button.dart';

void main() {
  testWidgets('calls onPressed when enabled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GradientButton(label: 'Go', onPressed: () => taps++),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets('is dimmed and inert when onPressed is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: GradientButton(label: 'Go', onPressed: null)),
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('Go'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 0.5, reason: 'a disabled button dims to half opacity');

    await tester.tap(find.text('Go'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a leading icon when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GradientButton(label: 'Go', icon: const Icon(Icons.bolt), onPressed: () {}),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });
}
