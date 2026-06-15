// Epic 14.3 (WI-10, D-Template): TitleIntro + TitleIntroProps. The built-in is a
// VideoTemplate built ONLY on the public element API, so it doubles as a worked
// example. build(props) produces a one-scene Video whose tree carries the title
// (and optional subtitle) and brand colors from the props, with the title
// animated in (a pop). TitleIntroProps is @immutable and value-equal.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/background/background.dart';
import 'package:fluvie/src/composition/video.dart';
import 'package:fluvie/src/core/animation_phase.dart';
import 'package:fluvie/src/templates/builtin/title_intro.dart';
import 'package:fluvie/src/templates/video_template.dart';

import 'tree_probe.dart';

// Non-default colors so the value-equality assertions exercise a real field.
const _accent = Color(0xFF6C5CE7);
const _bg = Color(0xFF123456);

void main() {
  group('TitleIntro is a VideoTemplate', () {
    test('extends VideoTemplate<TitleIntroProps>', () {
      expect(const TitleIntro(), isA<VideoTemplate<TitleIntroProps>>());
    });

    test('build produces a single-scene Video', () {
      final video = const TitleIntro().build(const TitleIntroProps(title: 'Hello'));
      expect(video, isA<Video>());
      expect(video.scenes, hasLength(1));
    });
  });

  group('build carries the props into the tree', () {
    test('the title text appears', () {
      final video = const TitleIntro().build(const TitleIntroProps(title: 'Year in review'));
      final strings = collectTexts(video).map((t) => t.data).toList();
      expect(strings, contains('Year in review'));
    });

    test('the subtitle text appears when given', () {
      final video = const TitleIntro().build(
        const TitleIntroProps(title: 'Title', subtitle: 'A subtitle'),
      );
      final strings = collectTexts(video).map((t) => t.data).toList();
      expect(strings, contains('A subtitle'));
    });

    test('no subtitle Text when the prop is null', () {
      final video = const TitleIntro().build(const TitleIntroProps(title: 'Solo'));
      final strings = collectTexts(video).map((t) => t.data).toList();
      expect(strings, ['Solo']);
    });

    test('the accent color styles the title', () {
      final video = const TitleIntro().build(
        const TitleIntroProps(title: 'Branded', accent: _accent),
      );
      final title = collectTexts(video).firstWhere((t) => t.data == 'Branded');
      expect(title.style?.color, _accent);
    });

    test('the background color comes from the props', () {
      final video = const TitleIntro().build(
        const TitleIntroProps(title: 'On bg', background: _bg),
      );
      expect(video.scenes.first.background, isA<Background>());
    });
  });

  group('the intro animation', () {
    test('the title pops in', () {
      final video = const TitleIntro().build(const TitleIntroProps(title: 'Pop'));
      final enters = collectMotionTargets(
        video,
      ).expand((t) => t.animations).where((a) => a.phase == AnimationPhase.enter);
      // At least one enter animation is present — the title's pop.
      expect(enters, isNotEmpty);
      // A pop is spring-timed by default.
      expect(enters.any((a) => a.spring != null), isTrue);
    });
  });

  group('TitleIntroProps is value-equal', () {
    test('same fields are equal and hash equal', () {
      const a = TitleIntroProps(title: 'T', subtitle: 'S', accent: _accent, background: _bg);
      const b = TitleIntroProps(title: 'T', subtitle: 'S', accent: _accent, background: _bg);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different title is not equal', () {
      const a = TitleIntroProps(title: 'A');
      const b = TitleIntroProps(title: 'B');
      expect(a, isNot(b));
    });

    test('a different subtitle is not equal', () {
      const a = TitleIntroProps(title: 'T', subtitle: 'one');
      const b = TitleIntroProps(title: 'T', subtitle: 'two');
      expect(a, isNot(b));
    });

    test('toString names the title', () {
      expect(const TitleIntroProps(title: 'Hi').toString(), contains('Hi'));
    });
  });
}
