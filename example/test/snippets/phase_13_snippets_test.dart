// The diagrams-and-webviews doc snippets compile and build (WI-40): the page
// pulls these via code-excerpt markers, so a failing build here means a doc
// would ship dead code.

// Mermaid/Html/WebView are @experimental; constructing them to assert the
// snippets build is the documented use, so the warning is expected here.
// ignore_for_file: experimental_member_use
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_13_snippets.dart';

void main() {
  test('the snapshot and mermaid snippets build widgets', () {
    expect(rasterizedCard(), isA<Widget>());
    expect(simpleDiagram(), isA<Mermaid>());
    expect(mermaidThemes('graph LR; A-->B;'), hasLength(2));
    expect(mermaidReveals('graph LR; A-->B;'), hasLength(3));
  });

  test('the web-snapshot menu builds Html and WebView', () {
    final widgets = webSnapshots();
    expect(widgets, hasLength(2));
    expect(widgets.first, isA<Html>());
    expect(widgets.last, isA<WebView>());
  });
}
