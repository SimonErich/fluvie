// The code-and-terminal-videos doc snippets compile and build (WI-40): the page
// pulls these via code-excerpt markers, so a failing build here means a doc
// would ship dead code.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_12_snippets.dart';

void main() {
  test('the code-language and reveal menus build Code widgets', () {
    expect(codeLanguages(), hasLength(3));
    expect(codeReveals('final x = 1;'), hasLength(3));
  });

  test('the focus, theme, diff, and markdown snippets build widgets', () {
    expect(focusedCode('final x = 1;'), isA<Code>());
    expect(themedCode(), isA<Widget>());
    expect(diffCode(), isA<Code>());
    expect(releaseNotes(), isA<Markdown>());
    expect(revealedMarkdown('# Hi'), isA<Markdown>());
  });
}
