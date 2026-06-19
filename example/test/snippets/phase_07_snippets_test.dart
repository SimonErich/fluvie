// The charts-and-data doc snippets compile and build (WI-40): the page pulls
// these via code-excerpt markers, so a failing build here means a doc would
// ship dead code.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_07_snippets.dart';

void main() {
  test('the chart-constructor menu builds all six shapes', () {
    expect(chartConstructors(), hasLength(6));
  });

  test('the stagger, animate, and tokens snippets build widgets', () {
    expect(staggeredBars(), isA<Chart>());
    expect(movedBars(), isA<Widget>());
    expect(themedChart(), isA<Widget>());
  });
}
