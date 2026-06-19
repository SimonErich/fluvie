// The Phase 14 doc snippets compile and build (WI-30): the export, template,
// multi-aspect, and frame-builder pages pull these via code-excerpt markers, so
// a failing build here means a doc would ship dead code.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_14_snippets.dart';

void main() {
  test('the export-mode snippets build the four §24 variants', () {
    expect(sharable().mode, ExportMode.mp4);
    expect(loopingThumb().mode, ExportMode.gif);
    expect(forCompositing().mode, ExportMode.imageSequence);
    expect(overlay().mode, ExportMode.transparent);
  });

  test('the exported reel carries its export mode and poster', () {
    final video = exportedReel();
    expect(video.export?.mode, ExportMode.mp4);
    expect(video.poster, const Time.seconds(1.5));
  });

  test('the template snippet builds a Video from props', () {
    final video = const GreetingTemplate().build(const GreetingProps(name: 'Sam'));
    expect(video, isA<Video>());
    expect(video.scenes, hasLength(1));
  });

  test('the aspect and frame-builder snippets build a widget', () {
    expect(headlineForAspect(), isA<Widget>());
    expect(sweepingBar(), isA<Widget>());
    expect(pulsingChip(Anchor('music')), isA<Widget>());
  });
}
