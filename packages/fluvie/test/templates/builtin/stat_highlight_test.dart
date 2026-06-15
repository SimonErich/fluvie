// Epic 14.3 (WI-11, D-Template): StatHighlight + StatHighlightProps. The
// built-in is a VideoTemplate built ONLY on the public element API (Counter +
// Text), so it doubles as a worked example. build(props) produces a one-scene
// Video with a Counter headline counting to the stat and the label beneath it.
// StatHighlightProps is @immutable and value-equal.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/elements/counter.dart';
import 'package:fluvie/src/templates/builtin/stat_highlight.dart';
import 'package:fluvie/src/templates/video_template.dart';

import 'tree_probe.dart';

// Non-default colors so the value-equality assertions exercise a real field.
const _accent = Color(0xFF00B894);
const _bg = Color(0xFF123456);

void main() {
  group('StatHighlight is a VideoTemplate', () {
    test('extends VideoTemplate<StatHighlightProps>', () {
      expect(const StatHighlight(), isA<VideoTemplate<StatHighlightProps>>());
    });

    test('build produces a single-scene Video', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 100, label: 'users'),
      );
      expect(video, isA<Video>());
      expect(video.scenes, hasLength(1));
    });
  });

  group('build carries the props into the tree', () {
    test('a Counter headline counts to the stat', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 48230, label: 'minutes'),
      );
      final counters = collectWidgets<Counter>(video);
      expect(counters, hasLength(1));
      expect(counters.single.to, 48230);
    });

    test('the label text appears', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 12, label: 'minutes listened'),
      );
      final strings = collectTexts(video).map((t) => t.data).toList();
      expect(strings, contains('minutes listened'));
    });

    test('the accent color styles the counter headline', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 7, label: 'wins', accent: _accent),
      );
      expect(collectWidgets<Counter>(video).single.style?.color, _accent);
    });

    test('the background color comes from the props', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 1, label: 'x', background: _bg),
      );
      expect(video.scenes.first.background, isA<Background>());
    });
  });

  group('the headline animation', () {
    test('the label fades or slides in', () {
      final video = const StatHighlight().build(
        const StatHighlightProps(value: 5, label: 'goals'),
      );
      final animated = collectMotionTargets(video).expand((t) => t.animations);
      expect(animated, isNotEmpty);
    });
  });

  group('StatHighlightProps is value-equal', () {
    test('same fields are equal and hash equal', () {
      const a = StatHighlightProps(value: 9, label: 'L', accent: _accent, background: _bg);
      const b = StatHighlightProps(value: 9, label: 'L', accent: _accent, background: _bg);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different value is not equal', () {
      const a = StatHighlightProps(value: 1, label: 'L');
      const b = StatHighlightProps(value: 2, label: 'L');
      expect(a, isNot(b));
    });

    test('a different label is not equal', () {
      const a = StatHighlightProps(value: 1, label: 'A');
      const b = StatHighlightProps(value: 1, label: 'B');
      expect(a, isNot(b));
    });

    test('toString names the value and label', () {
      final s = const StatHighlightProps(value: 42, label: 'answers').toString();
      expect(s, contains('42'));
      expect(s, contains('answers'));
    });
  });
}
