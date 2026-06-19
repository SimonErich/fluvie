// The Phase 8 doc snippets compile and build (WI-26): the documentation pulls
// these via code-excerpt markers, so a failing build here means a doc would
// ship dead code.

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_example/snippets/phase_08_snippets.dart';

void main() {
  test('the text, typewriter, and counter snippets build a widget', () {
    expect(animatedTitle(), isA<Widget>());
    expect(typedHeadline(), isA<Widget>());
    expect(viewsCounter(), isA<Widget>());
    expect(priceTag(), isA<Widget>());
    expect(shareOfVoice(), isA<Widget>());
  });

  test('the timeline snippet derives a non-zero scene length', () {
    final title = Anchor('title');
    final subtitle = Anchor('subtitle');
    final bullets = [Anchor('b1'), Anchor('b2')];
    final cta = Anchor('cta');
    final timeline = introTimeline(title, subtitle, bullets, cta);

    expect(timeline.duration.resolveFrames(_scope), greaterThan(0));
    expect(sequencedScene(timeline), isA<Scene>());
  });

  test('the image-constructor menu builds the four sources', () {
    expect(imageConstructors(Uint8List(0)), hasLength(4));
  });
}

const TimeScope _scope = _RootScope();

class _RootScope implements TimeScope {
  const _RootScope();
  @override
  int get fps => 30;
  @override
  int get startFrame => 0;
  @override
  int get durationFrames => 120;
  @override
  TimeScope? get parent => null;
}
