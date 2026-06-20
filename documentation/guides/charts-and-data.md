# Charts and data

Turn a `Map<String, num>` into an animated chart with one call. Each `Chart`
factory grows, draws, or sweeps itself in over its own window, so you describe
the data and the reveal happens for you:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (bar)" -->
```dart
Chart.bar(
  data: _revenue,
  growIn: 1.seconds,
  stagger: const Stagger.each(Time.frames(6)),
).animate([Animation.slideFade()]),
```

That paints four bars from `{'Q1': 42, 'Q2': 58, 'Q3': 71, 'Q4': 96}`, grows
each one from the baseline over one second, and offsets each bar's growth six
frames so the columns rise in a wave. Lesson 07 builds the whole data story.

## The chart family

Every chart is one public type, `Chart`, with a named factory per shape:

<!-- code-excerpt "example/lib/snippets/phase_07_snippets.dart (chart-constructors)" -->
```dart
Chart.bar(data: _revenue), // columns growing from the baseline
Chart.line(data: _revenue), // a polyline drawing on left to right
Chart.area(data: _revenue), // a line sweep filled to the baseline
Chart.pie(data: _revenue), // wedges sweeping clockwise from 12 o'clock
Chart.donut(data: _revenue), // a pie with an inner-radius hole
Chart.scatter(points: _points), // markers popping in with a spring
```

`bar`, `pie`, and `donut` take a `Map<String, num>` of category to value, in the
order you write it. `line`, `area`, and `scatter` take the same single-series
map, or call `.series([...])` with `ChartSeries` values for several colored
series at once.

## The reveal is built in

A chart's reveal is part of its constructor, not its `.animate()` list. You pass
a `Time` to the reveal parameter, and the chart resolves it against its own
window:

- `Chart.bar` and `Chart.area` grow over `growIn`.
- `Chart.line` and `Chart.area` draw on over `drawIn`.
- `Chart.pie` and `Chart.donut` sweep over `sweepIn`.
- `Chart.scatter` pops over `popIn`.

A relative time scales with the window. `growIn: 0.6.relative` grows over the
first 60 percent of the scene; `growIn: 1.seconds` grows over one second. The
default for every reveal is `0.6.relative`.

A line draws on by trimming its path left to right:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (line)" -->
```dart
Chart.line(data: _signups, drawIn: 1500.ms).animate([Animation.fadeIn()]),
```

A donut sweeps its wedges round and leaves a hole. `innerRadius` is the hole
size as a fraction of the outer radius:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (donut)" -->
```dart
Chart.donut(
  data: _channels,
  sweepIn: 1.seconds,
  innerRadius: 0.62,
).animate([Animation.slideFade()]),
```

## Stagger across segments

`Chart.bar` and `Chart.scatter` take a `stagger` that offsets each segment's
reveal, so the bars rise or the markers pop one after another. It reuses the
same `Stagger` you pass to a multi-child `.animate()`:

<!-- code-excerpt "example/lib/snippets/phase_07_snippets.dart (chart-stagger)" -->
```dart
Chart.bar(data: _revenue, stagger: const Stagger.each(Time.frames(6)));
```

The stagger delays the reveal of each bar, not the chart's window. Bar zero
starts at frame zero, bar one six frames later, and so on.

## .animate() for outer transforms

The reveal is intrinsic; `.animate()` adds outer transforms on top. A chart is a
plain widget, so it animates like any other element. The slide, fade, or camera
move composes with the grow or sweep:

<!-- code-excerpt "example/lib/snippets/phase_07_snippets.dart (chart-animate)" -->
```dart
Chart.bar(data: _revenue).animate([Animation.slideFade()]);
```

Keep pixel data in the reveal and motion in the list. The two never fight: the
chart paints its bars at the reveal progress, and the transform moves the whole
result.

## Theming with context.fluvie

Charts read their colors from `context.fluvie`. Wrap a subtree in a
`FluvieTokensScope` with a `FluvieTokens` value, and every chart inside picks up
the palette:

<!-- code-excerpt "example/lib/snippets/phase_07_snippets.dart (chart-tokens)" -->
```dart
FluvieTokensScope(
  tokens: const FluvieTokens(
    palette: ChartPalette([Color(0xFF00E0B0), Color(0xFF5B8DEF)]),
    axisColor: Color(0xFF546E7A),
    gridColor: Color(0x22FFFFFF),
    labelColor: Color(0xFFCFD8DC),
  ),
  child: Chart.bar(data: _revenue),
);
```

A chart with no scope above it uses the package fallback palette, so charts work
without any theme. A bar, segment, or marker cycles the palette by index; a
`ChartSeries.color` override wins over the slot the palette would pick.

The full `FluvieTheme` arrives in a later phase. It mounts a `FluvieTokensScope`
for you, so your charts read the theme through the same `context.fluvie` with no
change.

A counter headline reads like the charts it sits above:

<!-- code-excerpt "example/lib/lessons/07_charts.dart (headline)" -->
```dart
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Revenue this year', style: _headline),
      Counter.currency(
        to: 267000,
        duration: 1500.ms,
        style: _metric,
      ).animate([Animation.slideFade()]),
      const Text('up 38% over last year', style: _caption),
    ],
  ),
),
```

## Deterministic by construction

A chart is a pure function of its data, its reveal progress, and its theme
tokens. The same frame paints the same pixels every time, so charts cache and
golden like every other element.

## Where to next

- [Text and typography](text-and-typography.md): `Counter` and `Typewriter`, the
  elements that headline a data story.
- [Animating elements](timing-and-triggers.md): how `.animate()` and `Stagger`
  compose the outer motion a chart rides.
- [Determinism and caching](../advanced/determinism-and-caching.md): why the same
  data always renders the same chart.
