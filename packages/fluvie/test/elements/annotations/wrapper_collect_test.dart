// WI-22 (decision CollectibleChildren, the P12 DeviceFrame-bug guard): the four
// child-wrapping annotations (Spotlight / Callout / LowerThird / TitleCard) all
// implement CollectibleChildren, so a MediaCarrier nested inside one is gathered
// by the static collect pass before frame 0 (not missed and thrown at capture).
import 'package:flutter/widgets.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/composition/runtime/collectible_children.dart';
import 'package:fluvie/src/composition/runtime/media_collector.dart';
import 'package:fluvie/src/composition/scene.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/elements/annotations/callout.dart';
import 'package:fluvie/src/elements/annotations/lower_third.dart';
import 'package:fluvie/src/elements/annotations/spotlight.dart';
import 'package:fluvie/src/elements/annotations/title_card.dart';
import 'package:fluvie/src/elements/image.dart';

const MediaSource _logo = MediaSource.asset('fixtures/swatch.png');

Scene _scene(Widget child) => Scene(duration: const Time.seconds(1), children: [child]);

void main() {
  group('the child-wrapping annotations implement CollectibleChildren', () {
    test('Spotlight returns its dimmed child', () {
      final spotlight = Spotlight.on(
        region: const Rect.fromLTWH(0, 0, 50, 50),
        child: Image.asset('fixtures/swatch.png'),
      );
      expect(spotlight, isA<CollectibleChildren>());
      expect((spotlight as CollectibleChildren).collectibleChildren, hasLength(1));
    });

    test('Callout returns its annotated child', () {
      final callout = Callout(
        label: 'Look here',
        target: const Offset(80, 80),
        child: Image.asset('fixtures/swatch.png'),
      );
      expect(callout, isA<CollectibleChildren>());
    });

    test('LowerThird returns its background child when present', () {
      final lowerThird = LowerThird(name: 'Ada', child: Image.asset('fixtures/swatch.png'));
      expect(lowerThird, isA<CollectibleChildren>());
      expect((lowerThird as CollectibleChildren).collectibleChildren, hasLength(1));
    });

    test('LowerThird with no child returns no collectible children', () {
      const lowerThird = LowerThird(name: 'Ada');
      expect((lowerThird as CollectibleChildren).collectibleChildren, isEmpty);
    });

    test('TitleCard returns its background child when present', () {
      final titleCard = TitleCard(title: 'Chapter 1', child: Image.asset('fixtures/swatch.png'));
      expect(titleCard, isA<CollectibleChildren>());
      expect((titleCard as CollectibleChildren).collectibleChildren, hasLength(1));
    });
  });

  group('a nested Image is gathered by collectMediaSources (the P12 bug guard)', () {
    test('through a Spotlight', () {
      final scenes = [
        _scene(
          Spotlight.on(
            region: const Rect.fromLTWH(0, 0, 50, 50),
            child: Image.asset('fixtures/swatch.png'),
          ),
        ),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('through a Callout', () {
      final scenes = [
        _scene(
          Callout(
            label: 'Note',
            target: const Offset(40, 40),
            child: Image.asset('fixtures/swatch.png'),
          ),
        ),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('through a LowerThird', () {
      final scenes = [_scene(LowerThird(name: 'Ada', child: Image.asset('fixtures/swatch.png')))];
      expect(collectMediaSources(scenes), {_logo});
    });

    test('through a TitleCard', () {
      final scenes = [
        _scene(TitleCard(title: 'Chapter 1', child: Image.asset('fixtures/swatch.png'))),
      ];
      expect(collectMediaSources(scenes), {_logo});
    });
  });
}
