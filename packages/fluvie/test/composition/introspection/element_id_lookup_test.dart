import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';

/// A minimal deck document around [scenes], sized like the parity fixtures.
Map<String, Object?> _document(List<Map<String, Object?>> scenes) => {
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'fps': 30,
  'scenes': scenes,
};

TimelineIntrospection _introspect(List<Map<String, Object?>> scenes) =>
    introspectTimeline(VideoSpec.fromJson(_document(scenes)).build());

Map<String, Object?> _text(
  String id, {
  List<Map<String, Object?>>? animate,
  Map<String, Object?>? transform,
  String? anchor,
}) => {
  'id': id,
  'type': 'Text',
  'text': id,
  'transform': ?transform,
  'anchor': ?anchor,
  'animate': ?animate,
};

void main() {
  group('elementById on spec-built decks', () {
    test('a placed element resolves by its spec id', () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            _text(
              'hero',
              transform: {'x': 0.5, 'y': 0.5, 'w': 0.5, 'h': 0.5},
              animate: [
                {'preset': 'fadeIn', 'duration': '30f'},
              ],
            ),
          ],
        },
      ]);
      final element = introspection.elementById('hero');
      expect(element, isNotNull);
      expect(element!.elementId, 'hero');
      expect(element.sceneIndex, 0);
      expect(element.animations.single.span, const FrameSpan(0, 30));
      expect(element.toString(), contains('hero'));
      expect(introspection.scenes[0].elementById('hero'), same(element));
    });

    test('an unplaced element resolves by its spec id', () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            _text(
              'kicker',
              animate: [
                {'preset': 'fadeIn', 'duration': '15f'},
              ],
            ),
          ],
        },
      ]);
      final element = introspection.elementById('kicker');
      expect(element, isNotNull);
      expect(element!.elementId, 'kicker');
      expect(element.animations.single.span, const FrameSpan(0, 15));
    });

    test('an unknown id resolves to null, flat and scene-scoped', () {
      final introspection = _introspect([
        {
          'duration': '1s',
          'children': [
            _text(
              'only',
              animate: [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
            ),
          ],
        },
      ]);
      expect(introspection.elementById('missing'), isNull);
      expect(introspection.scenes[0].elementById('missing'), isNull);
    });

    test('chained whenEnds triggers resolve absolutely through id lookup', () {
      final introspection = _introspect([
        {'duration': '2s', 'children': <Map<String, Object?>>[]},
        {
          'duration': '4s',
          'children': [
            _text(
              'title',
              anchor: 'intro',
              animate: [
                {'preset': 'fadeIn', 'duration': '30f'},
              ],
            ),
            _text(
              'kicker',
              animate: [
                {
                  'preset': 'slideFadeIn',
                  'duration': '15f',
                  'at': {'kind': 'whenEnds', 'anchor': 'intro'},
                },
              ],
            ),
          ],
        },
      ]);
      final title = introspection.elementById('title')!;
      final kicker = introspection.elementById('kicker')!;
      expect(title.sceneIndex, 1);
      expect(title.animations.single.span, const FrameSpan(60, 90));
      expect(kicker.animations.single.span, const FrameSpan(90, 105));
      expect(kicker.animations.single.at, isA<WhenEndsTrigger>());
    });

    test('a multi-scene deck keeps unique ids apart', () {
      final introspection = _introspect([
        {
          'duration': '1s',
          'children': [
            _text(
              'opening',
              animate: [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
            ),
          ],
        },
        {
          'duration': '1s',
          'children': [
            _text(
              'closing',
              animate: [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
            ),
          ],
        },
      ]);
      expect(introspection.elementById('opening')!.sceneIndex, 0);
      expect(introspection.elementById('closing')!.sceneIndex, 1);
      expect(introspection.elementById('closing')!.animations.single.span, const FrameSpan(30, 40));
    });

    test('an id duplicated across scenes: flat lookup is first-wins, scene lookup is exact', () {
      final introspection = _introspect([
        {
          'duration': '1s',
          'children': [
            _text(
              'title',
              animate: [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
            ),
          ],
        },
        {
          'duration': '1s',
          'children': [
            _text(
              'title',
              animate: [
                {'preset': 'fadeIn', 'duration': '20f'},
              ],
            ),
          ],
        },
      ]);
      expect(introspection.elementById('title')!.sceneIndex, 0);
      expect(
        introspection.scenes[0].elementById('title')!.animations.single.span,
        const FrameSpan(0, 10),
      );
      expect(
        introspection.scenes[1].elementById('title')!.animations.single.span,
        const FrameSpan(30, 50),
      );
    });

    test('an id duplicated inside one scene resolves first-wins in walk order', () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            _text(
              'dup',
              animate: [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
            ),
            _text(
              'dup',
              animate: [
                {'preset': 'fadeIn', 'duration': '20f'},
              ],
            ),
          ],
        },
      ]);
      expect(introspection.elementById('dup')!.animations.single.span, const FrameSpan(0, 10));
      expect(
        introspection.scenes[0].elementById('dup')!.animations.single.span,
        const FrameSpan(0, 10),
      );
    });
  });

  group('elementById and groups', () {
    test('a group child resolves by its own id, absolutely', () {
      final introspection = _introspect([
        {'duration': '1s', 'children': <Map<String, Object?>>[]},
        {
          'duration': '2s',
          'children': [
            {
              'id': 'g',
              'type': 'Group',
              'transform': {'x': 0.5, 'y': 0.5, 'w': 0.8, 'h': 0.8},
              'children': [
                _text(
                  'gc',
                  animate: [
                    {'preset': 'fadeIn', 'duration': '30f'},
                  ],
                ),
              ],
            },
          ],
        },
      ]);
      final child = introspection.elementById('gc');
      expect(child, isNotNull);
      expect(child!.sceneIndex, 1);
      expect(child.animations.single.span, const FrameSpan(30, 60));
    });

    test('a group with no animations of its own binds to no span', () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            {
              'id': 'g',
              'type': 'Group',
              'children': [
                _text(
                  'gc',
                  animate: [
                    {'preset': 'fadeIn', 'duration': '30f'},
                  ],
                ),
              ],
            },
          ],
        },
      ]);
      expect(introspection.elementById('g'), isNull);
      expect(introspection.elementById('gc'), isNotNull);
    });

    test('an animated group and its animated child resolve separately', () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            {
              'id': 'g',
              'type': 'Group',
              'animate': [
                {'preset': 'fadeIn', 'duration': '10f'},
              ],
              'children': [
                _text(
                  'gc',
                  animate: [
                    {'preset': 'fadeIn', 'duration': '30f'},
                  ],
                ),
              ],
            },
          ],
        },
      ]);
      expect(introspection.elementById('g')!.animations.single.span, const FrameSpan(0, 10));
      expect(introspection.elementById('gc')!.animations.single.span, const FrameSpan(0, 30));
    });

    test("an anonymous animated child never inherits its group's id", () {
      final introspection = _introspect([
        {
          'duration': '2s',
          'children': [
            {
              'id': 'g',
              'type': 'Group',
              'children': [
                {
                  'type': 'Text',
                  'text': 'anonymous',
                  'animate': [
                    {'preset': 'fadeIn', 'duration': '30f'},
                  ],
                },
              ],
            },
          ],
        },
      ]);
      expect(introspection.elementById('g'), isNull);
      final anonymous = introspection.scenes[0].elements.single;
      expect(anonymous.elementId, isNull);
    });
  });

  group('SpecElementId in widget-authored decks', () {
    test('widget-authored elements carry no id and elementById finds nothing', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      expect(introspection.scenes[0].elements.single.elementId, isNull);
      expect(introspection.elementById('anything'), isNull);
    });

    test('a hand-placed SpecElementId joins its animated child to the id', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              SpecElementId(
                id: 'manual',
                child: const SizedBox().animate([
                  Animation.fadeIn(duration: const Time.seconds(1)),
                ]),
              ),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      final element = introspection.elementById('manual');
      expect(element, isNotNull);
      expect(element!.elementId, 'manual');
      expect(element.animations.single.span, const FrameSpan(0, 30));
    });

    test('a SpecElementId over a non-animated child binds to no span', () {
      final video = Video(
        scenes: [
          Scene(
            duration: const Time.seconds(2),
            children: [
              const SpecElementId(id: 'static', child: SizedBox()),
              const SizedBox().animate([Animation.fadeIn(duration: const Time.seconds(1))]),
            ],
          ),
        ],
      );
      final introspection = introspectTimeline(video);
      expect(introspection.elementById('static'), isNull);
      expect(introspection.scenes[0].elements.single.elementId, isNull);
    });
  });

  group('the SpecElementId widget', () {
    test('exposes its child to the structural walk', () {
      const child = SizedBox();
      const marker = SpecElementId(id: 'x', child: child);
      expect(marker.collectibleChildren, [same(child)]);
    });

    testWidgets('is render-transparent: it mounts its child unchanged', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SpecElementId(id: 'x', child: Text('through')),
        ),
      );
      expect(find.text('through'), findsOneWidget);
    });
  });
}
