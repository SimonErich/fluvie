import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_ai/fluvie_ai.dart';
import 'package:fluvie_example/inspector/generate_panel.dart';

const _validSpec =
    '{"fluvieSpec":1,"size":"square","fps":30,"scenes":[{"duration":"2s",'
    '"children":[{"type":"Text","text":"Hi"}]}]}';

void main() {
  testWidgets('typing a prompt and generating shows the spec summary and JSON', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiClientProvider.overrideWithValue(FakeAiClient([_validSpec])),
        ],
        child: const MaterialApp(home: Scaffold(body: GeneratePanel())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'a square title card');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 scene(s)'), findsOneWidget);
    expect(find.textContaining('fluvieSpec'), findsOneWidget);
  });
}
