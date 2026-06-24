import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/ai_assistant_panel.dart';
import 'package:fluvie_example/playground/ai_author_backend.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_example/theme/widgets/gradient_button.dart';

import 'fake_ai_author_backend.dart';
import 'fake_playground_backend.dart';

const _validCode = 'Video build() => Video(scenes: const []);';

Future<void> _pump(WidgetTester tester, FakeAiAuthorBackend ai) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiAuthorBackendProvider.overrideWithValue(ai),
        playgroundBackendProvider.overrideWithValue(FakePlaygroundBackend()),
      ],
      child: const MaterialApp(home: Scaffold(body: AiAssistantPanel())),
    ),
  );
  await tester.pump();
}

Future<void> _generate(WidgetTester tester, String prompt) async {
  await tester.enterText(find.byType(TextField), prompt);
  await tester.tap(find.widgetWithText(GradientButton, 'Generate video'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('idle shows the prompt field and a generate button', (tester) async {
    await _pump(tester, FakeAiAuthorBackend());

    expect(find.text('Generate a video with AI'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Generate video'), findsOneWidget);
  });

  testWidgets('generating then ready shows the editor and the AI button', (tester) async {
    await _pump(tester, FakeAiAuthorBackend(code: _validCode));
    await _generate(tester, 'a blue intro');

    expect(find.byType(CodeField), findsOneWidget);
    expect(find.widgetWithText(GradientButton, 'Render'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'AI'), findsOneWidget);
  });

  testWidgets('the AI button opens the edit overlay', (tester) async {
    await _pump(tester, FakeAiAuthorBackend(code: _validCode));
    await _generate(tester, 'a blue intro');

    await tester.tap(find.widgetWithText(OutlinedButton, 'AI'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
  });

  testWidgets('an edit failure surfaces the message over the editor', (tester) async {
    final ai = FakeAiAuthorBackend(code: _validCode);
    await _pump(tester, ai);
    await _generate(tester, 'a blue intro');

    // The edit call fails with a friendly, explainable message.
    ai.error = const AiAuthorException('Free limit reached.');
    await tester.tap(find.widgetWithText(OutlinedButton, 'AI'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'make it red',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Free limit reached.'), findsOneWidget);
  });
}
