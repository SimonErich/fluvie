// Compiled, tested snippets for the charts-and-data docs. They live
// here, not hand-typed in Markdown, so the documentation never drifts from a
// real API. Each `#docregion` flows into one fence via a `<!-- code-excerpt -->`
// marker.

import 'package:flutter/widgets.dart' hide Animation, Image;
import 'package:fluvie/fluvie.dart';

const _revenue = {'Jan': 30, 'Feb': 45, 'Mar': 38};
const _points = [ChartPoint(x: 1, y: 4), ChartPoint(x: 2, y: 9)];

/// The chart family is one public type, `Chart`, with a named factory per shape.
/// Each reveal is built into its own constructor.
List<Chart> chartConstructors() => [
  // #docregion chart-constructors
  Chart.bar(data: _revenue), // columns growing from the baseline
  Chart.line(data: _revenue), // a polyline drawing on left to right
  Chart.area(data: _revenue), // a line sweep filled to the baseline
  Chart.pie(data: _revenue), // wedges sweeping clockwise from 12 o'clock
  Chart.donut(data: _revenue), // a pie with an inner-radius hole
  Chart.scatter(points: _points), // markers popping in with a spring
  // #enddocregion chart-constructors
];

/// A bar chart whose columns rise in a wave: `stagger` reuses the same `Stagger`
/// a multi-child `.animate()` takes.
Chart staggeredBars() =>
    // #docregion chart-stagger
    Chart.bar(data: _revenue, stagger: const Stagger.each(Time.frames(6)));
// #enddocregion chart-stagger

/// An outer move composed over the intrinsic grow: `.animate()` rides on top of
/// the chart's own reveal.
Widget movedBars() =>
    // #docregion chart-animate
    Chart.bar(data: _revenue).animate([Animation.slideFade()]);
// #enddocregion chart-animate

/// Theming a chart by wrapping it in a `FluvieTokensScope`: the chart reads the
/// series palette and the axis, grid, and label colors from the scope.
Widget themedChart() =>
    // #docregion chart-tokens
    FluvieTokensScope(
      tokens: const FluvieTokens(
        palette: ChartPalette([Color(0xFF00E0B0), Color(0xFF5B8DEF)]),
        axisColor: Color(0xFF546E7A),
        gridColor: Color(0x22FFFFFF),
        labelColor: Color(0xFFCFD8DC),
      ),
      child: Chart.bar(data: _revenue),
    );
// #enddocregion chart-tokens
