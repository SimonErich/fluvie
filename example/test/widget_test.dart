import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/main.dart';

void main() {
  testWidgets('Verify Fluvie Generator UI', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to wrap MyApp in ProviderScope because main() does it, but the test pumps MyApp directly.
    // Wait, MyApp in main.dart is wrapped in ProviderScope in main().
    // But here we pump MyApp. MyApp itself doesn't contain ProviderScope.
    // So we need to wrap it here.
    
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Verify that the title is present
    expect(find.text('Fluvie Generator'), findsOneWidget);

    // Verify that the Render Video button is present
    expect(find.text('Render Video'), findsOneWidget);
    
    // Verify that the initial frame text is not there (it appears when rendering)
    expect(find.textContaining('Rendering frame:'), findsNothing);
  });
}
