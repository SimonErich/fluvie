import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/playground/playground_code_editor.dart';
import 'package:fluvie_example/playground/playground_view_model.dart';
import 'package:fluvie_server/client.dart';

import 'fake_playground_backend.dart';

const _errorDiagnostic = ApiCodeDiagnostic(
  severity: ApiDiagnosticSeverity.error,
  message: "Expected to find ';'.",
  line: 2,
  column: 1,
);

CodeController _controller(WidgetTester tester) =>
    tester.widget<CodeField>(find.byType(CodeField)).controller;

Future<ProviderContainer> _pump(WidgetTester tester, FakePlaygroundBackend backend) async {
  final container = ProviderContainer(
    overrides: [playgroundBackendProvider.overrideWithValue(backend)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: PlaygroundCodeEditor())),
    ),
  );
  return container;
}

void main() {
  testWidgets('renders the editor seeded with the starter snippet', (tester) async {
    await _pump(tester, FakePlaygroundBackend());

    expect(find.byType(CodeField), findsOneWidget);
    expect(_controller(tester).text, contains("import 'package:fluvie/fluvie.dart';"));
    expect(find.textContaining('No problems'), findsOneWidget);
  });

  testWidgets('a validation error becomes an editor marker on the right line', (tester) async {
    final backend = FakePlaygroundBackend(
      validateResult: const ApiValidationResult(ok: false, diagnostics: [_errorDiagnostic]),
    );
    final container = await _pump(tester, backend);

    // Drive a validation directly (the debounce timer is bypassed) and let the
    // editor map the diagnostics onto the controller.
    await container.read(playgroundViewModelProvider.notifier).validate('bad code');
    await tester.pump();

    final issues = _controller(tester).analysisResult.issues;
    expect(issues, isNotEmpty);
    expect(issues.single.type, IssueType.error);
    // Confirm the Issue line base: the diagnostic is 1-based line 2 and the
    // editor must hand the controller the same 1-based line.
    expect(issues.single.line, _errorDiagnostic.line);
    expect(find.textContaining('1 problem'), findsOneWidget);
  });

  testWidgets('typing after the debounce triggers a validate call', (tester) async {
    final backend = FakePlaygroundBackend();
    await _pump(tester, backend);

    await tester.enterText(find.byType(CodeField), 'Video build() => Video(scenes: []);');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(backend.validateCalls, greaterThanOrEqualTo(1));
    expect(backend.lastValidatedCode, contains('Video'));
  });
}
