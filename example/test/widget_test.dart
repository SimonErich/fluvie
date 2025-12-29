import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/main.dart';

void main() {
  testWidgets('Verify Fluvie Gallery UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to wrap MyApp in ProviderScope because main() does it, but the test pumps MyApp directly.
    // Wait, MyApp in main.dart is wrapped in ProviderScope in main().
    // But here we pump MyApp. MyApp itself doesn't contain ProviderScope.
    // So we need to wrap it here.

    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that the title is present
    expect(find.text('Fluvie Gallery'), findsOneWidget);

    // Verify the initial state shows instruction to select an example
    expect(find.text('Select an example from the drawer'), findsOneWidget);

    // Open the drawer to access the example list
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Verify that example list is visible in the drawer
    expect(find.byType(ListView), findsOneWidget);
  });
}
