import 'package:flutter/material.dart' hide Animation, Clip, Image, Tween;
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/lessons/lesson.dart';

const _headline = TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold);
const _metric = TextStyle(color: Color(0xFF00E0B0), fontSize: 120, fontWeight: FontWeight.bold);
const _caption = TextStyle(color: Color(0xFFB0BEC5), fontSize: 30);

/// The brand palette this story themes every chart with: a
/// FluvieTokensScope wraps the scenes, so the charts pick these hues up from
/// `context.fluvie` without any per-chart color.
const _brand = FluvieTokens(
  palette: ChartPalette([
    Color(0xFF00E0B0), // mint
    Color(0xFF5B8DEF), // sky
    Color(0xFFFFB020), // gold
    Color(0xFFE5484D), // coral
  ]),
  axisColor: Color(0xFF546E7A),
  gridColor: Color(0x22FFFFFF),
  labelColor: Color(0xFFCFD8DC),
);

/// One quarter of revenue, the bar story's data.
const _revenue = <String, num>{'Q1': 42, 'Q2': 58, 'Q3': 71, 'Q4': 96};

/// Weekly signups, the line story's draw-on data.
const _signups = <String, num>{'W1': 12, 'W2': 26, 'W3': 21, 'W4': 38, 'W5': 47, 'W6': 63};

/// The traffic split, the donut story's data.
const _channels = <String, num>{'Search': 48, 'Social': 27, 'Direct': 17, 'Email': 8};

/// Lesson 07 — a data story: a headline metric, then the chart
/// family revealing in turn, all themed from one FluvieTokensScope.
const lesson07Charts = Lesson(
  id: '07_charts',
  title: 'A data story',
  intro:
      'A Counter headline, a bar chart that grows in a stagger, a line that '
      'draws on left to right, and a donut that sweeps round. One '
      'FluvieTokensScope themes every chart from the same brand palette. The '
      'reveal is built into each chart; .animate() adds the outer slide.',
  video: lesson07Video,
);

/// Builds the lesson 07 composition: a four-scene, 11 second square story.
///
/// A single [FluvieTokensScope] wraps all four scenes, so every chart reads the
/// same brand palette from `context.fluvie`. Each chart's reveal
/// is intrinsic (`reveal` / `reveal` / `reveal` resolve against the scene
/// window); `.animate()` only adds the outer slide-in. The bar scene draws an
/// [Arrow.to] at the Q4 peak and the line scene puts a [Spotlight.on] the
/// week-six surge, both at explicit positions.
Video lesson07Video() {
  return Video(
    size: VideoSize.square,
    poster: 4.seconds,
    scenes: [
      _headlineScene(),
      _barScene(),
      _lineScene(),
      _donutScene(),
    ],
  );
}

/// Wraps [child] in the brand theme so its charts read the brand palette.
Widget _themed(Widget child) => FluvieTokensScope(tokens: _brand, child: child);

/// Scene 1: the headline number that opens the story.
Scene _headlineScene() => Scene(
  duration: 2500.ms,
  background: Background.gradient(const [Color(0xFF0B1F2A), Color(0xFF14323F)]),
  children: [
    // #docregion headline
    Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Revenue this year', style: _headline),
          Counter.currency(
            to: 267000,
            reveal: 1500.ms,
            style: _metric,
          ).animate([Animation.slideFade()]),
          const Text('up 38% over last year', style: _caption),
        ],
      ),
    ),
    // #enddocregion headline
  ],
);

/// Scene 2: the quarterly bars, growing in a stagger.
Scene _barScene() => Scene(
  duration: 3.seconds,
  background: Background.color(const Color(0xFF0B1F2A)),
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(64, 120, 64, 96),
      child: _themed(
        // #docregion bar
        Chart.bar(
          data: _revenue,
          reveal: 1.seconds,
          stagger: const Stagger.each(Time.frames(6)),
        ).animate([Animation.slideFade()]),
        // #enddocregion bar
      ),
    ),
    const Positioned(
      top: 56,
      left: 64,
      child: Text('Revenue by quarter', style: _headline),
    ),
    // An Arrow drawing on to the Q4 bar's peak, with a label beside it. The
    // Q4 bar is the rightmost and tallest; its top sits near (910, 300) on the
    // 1080-square canvas. The arrow draws in over half a second.
    // #docregion arrow
    Positioned.fill(
      child: Arrow.to(
        from: const Offset(720, 200),
        to: const Offset(910, 300),
        reveal: 500.ms,
      ),
    ),
    // #enddocregion arrow
    const Positioned(top: 150, left: 560, child: Text('best quarter', style: _caption)),
  ],
);

/// Scene 3: the signups line, drawing on left to right, with a spotlight on the
/// week-six surge.
Scene _lineScene() => Scene(
  duration: 3.seconds,
  background: Background.color(const Color(0xFF0B1F2A)),
  children: [
    // The Spotlight dims the scene and grows a clear hole over the W6 surge (the
    // top-right of the line area) so the eye lands on the peak. The line chart is
    // its child, rendered behind the dim, and the hole opens over half a second.
    // #docregion spotlight
    Spotlight.on(
      region: const Rect.fromLTWH(780, 240, 240, 240),
      reveal: 500.ms,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 120, 64, 96),
        child: _themed(
          // #docregion line
          Chart.line(data: _signups, reveal: 1500.ms).animate([Animation.fadeIn()]),
          // #enddocregion line
        ),
      ),
    ),
    // #enddocregion spotlight
    const Positioned(
      top: 56,
      left: 64,
      child: Text('Signups per week', style: _headline),
    ),
  ],
);

/// Scene 4: the channel mix, sweeping round as a donut.
Scene _donutScene() => Scene(
  duration: 2500.ms,
  background: Background.color(const Color(0xFF0B1F2A)),
  children: [
    Center(
      child: SizedBox(
        width: 520,
        height: 520,
        child: _themed(
          // #docregion donut
          Chart.donut(
            data: _channels,
            reveal: 1.seconds,
            innerRadius: 0.62,
          ).animate([Animation.slideFade()]),
          // #enddocregion donut
        ),
      ),
    ),
    const Positioned(
      top: 56,
      left: 64,
      child: Text('Traffic by channel', style: _headline),
    ),
  ],
);
