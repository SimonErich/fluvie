// The scenes-and-transitions doc snippet compiles and builds (WI-40): the page
// pulls it via a code-excerpt marker, so a failing build here means a doc would
// ship dead code.

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie_example/snippets/phase_06_snippets.dart';

void main() {
  test('the transition menu lists the five kinds', () {
    final kinds = transitions().map((t) => t.kind).toSet();
    expect(transitions(), hasLength(5));
    expect(kinds, hasLength(5));
  });
}
