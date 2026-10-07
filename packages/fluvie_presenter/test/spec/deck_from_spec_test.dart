import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

VideoSpec _spec(Map<String, Object?> scene, {Map<String, Object?> top = const {}}) =>
    VideoSpec.fromJson({
      'fluvieSpec': 1,
      'size': {'width': 640, 'height': 360},
      ...top,
      'scenes': [scene],
    });

Map<String, Object?> _scene({
  required List<Object?> children,
  Object? steps,
  Object? notes,
}) => {
  'duration': '4s',
  'children': children,
  'steps': ?steps,
  'notes': ?notes,
};

const Map<String, Object?> _title = {'id': 'el-a', 'type': 'Text', 'text': 'A'};
const Map<String, Object?> _middle = {'id': 'el-b', 'type': 'Text', 'text': 'B'};
const Map<String, Object?> _box = {'id': 'el-c', 'type': 'Box', 'color': '#6C5CE7'};

void main() {
  group('the video mirrors the spec', () {
    test('composition-wide settings pass through', () {
      final spec = _spec(
        _scene(children: const [_title]),
        top: const {
          'fps': 24,
          'poster': '10f',
          'transition': {'kind': 'crossFade', 'duration': '12f'},
          'export': {'mode': 'mp4', 'quality': 'high'},
        },
      );
      final deck = deckFromSpec(spec);
      expect(deck.size, spec.size);
      expect(deck.fps, 24);
      expect(deck.poster, spec.poster);
      expect(deck.transition, spec.transition);
      expect(deck.export, spec.export);
      expect(deck.scenes, hasLength(1));
    });

    test('theme tokens resolve and theme motion composes, exactly as in spec.build()', () {
      final spec = _spec(
        _scene(
          children: const [
            _title,
            {
              'id': 'el-t',
              'type': 'Box',
              'color': {'token': 'accent'},
            },
          ],
          steps: const [
            {
              'elements': ['el-t'],
            },
          ],
        ),
        top: const {
          'motionDefaults': {'duration': '30f'},
          'theme': {
            'palette': {'accent': '#FF6C5CE7'},
            'motion': {'duration': '12f', 'ease': 'out'},
          },
        },
      );
      final deck = deckFromSpec(spec);
      expect(deck.motionDefaults, spec.effectiveMotionDefaults);
      expect(deck.motionDefaults, spec.build().motionDefaults);
      expect(deck.scenes.single.children.whereType<Stop>(), hasLength(1));
    });

    test('a spec without steps or notes builds the same children as spec.build()', () {
      final spec = _spec(_scene(children: const [_title, _box]));
      final deck = deckFromSpec(spec);
      final plain = spec.build();
      final deckScene = deck.scenes.single;
      final plainScene = plain.scenes.single;
      expect(deckScene.children, hasLength(plainScene.children.length));
      for (var i = 0; i < plainScene.children.length; i++) {
        expect(deckScene.children[i].runtimeType, plainScene.children[i].runtimeType);
      }
      expect(deckScene.duration, plainScene.duration);
    });

    test('audio tracks thread to Video.audio and Scene.audio, exactly as in spec.build()', () {
      final spec = _spec(
        {
          'duration': '4s',
          'audio': [
            {
              'kind': 'sfx',
              'source': {'kind': 'asset', 'value': 'audio/whoosh.mp3'},
              'at': {'kind': 'at', 'time': '500ms'},
              'volume': 0.6,
            },
          ],
          'children': const [_title],
        },
        top: const {
          'audio': [
            {
              'kind': 'music',
              'source': {'kind': 'file', 'value': '/home/ada/music/bed.mp3'},
              'volume': 0.8,
              'loop': true,
              'track': 'bed',
            },
          ],
        },
      );
      final deck = deckFromSpec(spec);
      final music = deck.audio.single;
      expect(music.isSfx, isFalse);
      expect(music.source, '/home/ada/music/bed.mp3');
      expect(music.volume, closeTo(0.8, 1e-9));
      expect(music.loop, isTrue);
      expect(identical(music.track, spec.anchors.resolve('bed')), isTrue);
      final sfx = deck.scenes.single.audio.single;
      expect(sfx.isSfx, isTrue);
      expect(sfx.source, 'audio/whoosh.mp3');
      expect(sfx.at, const Trigger.at(Time.ms(500)));
      expect(sfx.volume, closeTo(0.6, 1e-9));
      final plain = spec.build();
      expect(music.source, plain.audio.single.source);
      expect(sfx.source, plain.scenes.single.audio.single.source);
    });
  });

  group('masters apply', () {
    Map<String, Object?> masteredScene({Object? steps}) => {
      'duration': '4s',
      'master': 'content',
      'fills': {
        'title': {'id': 'el-fill', 'type': 'Text', 'text': 'Filled'},
      },
      'children': const [
        {'id': 'el-extra', 'type': 'Box', 'color': '#6C5CE7'},
      ],
      'steps': ?steps,
    };

    const mastersTop = <String, Object?>{
      'masters': {
        'content': {
          'background': {'kind': 'color', 'color': '#FF101018'},
          'children': [
            {'type': 'Box', 'color': '#FF6C5CE7'},
            {
              'type': 'Placeholder',
              'slot': 'title',
              'transform': {'x': 0.5, 'y': 0.3},
            },
          ],
        },
      },
    };

    test('an adopting scene builds chrome, fill, and extras, exactly as in spec.build()', () {
      final spec = _spec(masteredScene(), top: mastersTop);
      final deck = deckFromSpec(spec);
      final plain = spec.build();
      final deckScene = deck.scenes.single;
      final plainScene = plain.scenes.single;
      expect(deckScene.children, hasLength(plainScene.children.length));
      for (var i = 0; i < plainScene.children.length; i++) {
        expect(deckScene.children[i].runtimeType, plainScene.children[i].runtimeType);
      }
      expect(deckScene.background, isNotNull);
    });

    test('a step reveals a fill: the fill lands inside its Stop', () {
      final spec = _spec(
        masteredScene(
          steps: const [
            {
              'elements': ['el-fill'],
            },
          ],
        ),
        top: mastersTop,
      );
      final deck = deckFromSpec(spec);
      expect(deck.scenes.single.children.whereType<Stop>(), hasLength(1));
      expect(validateStepPlan(spec), isEmpty);
    });

    test('the scene-alone sweep keeps masters, so errors attribute per scene', () {
      final spec = VideoSpec.fromJson({
        'fluvieSpec': 1,
        'size': {'width': 640, 'height': 360},
        ...mastersTop,
        'scenes': [
          masteredScene(
            steps: const [
              {
                'elements': ['el-fill'],
              },
            ],
          ),
          {
            'duration': '4s',
            'children': const [
              {
                'id': 'el-solo',
                'type': 'Text',
                'text': 'x',
                'anchor': 'late',
                'animate': [
                  {'preset': 'fadeIn', 'duration': '30f'},
                ],
              },
              {
                'id': 'el-bad',
                'type': 'Text',
                'text': 'y',
                'animate': [
                  {
                    'preset': 'fadeIn',
                    'at': {'kind': 'whenEnds', 'anchor': 'late'},
                  },
                ],
              },
            ],
            'steps': const [
              {
                'elements': ['el-bad'],
              },
            ],
          },
        ],
      });
      final errors = validateStepPlan(spec);
      expect(errors, isNotEmpty);
      expect(errors.every((error) => error.message.startsWith('scene 1:')), isTrue);
    });
  });

  group('steps become stops', () {
    test('each step entry becomes one Stop, ordered by the list', () {
      final spec = _spec(
        _scene(
          children: const [_title, _middle, _box],
          steps: const [
            {
              'elements': ['el-b'],
            },
            {
              'elements': ['el-c'],
            },
          ],
        ),
      );
      final children = deckFromSpec(spec).scenes.single.children;
      expect(children, hasLength(3));
      expect(children[0], isNot(isA<Stop>()));
      expect(children[1], isA<Stop>());
      expect((children[1] as Stop).order, 0);
      expect(children[2], isA<Stop>());
      expect((children[2] as Stop).order, 1);
    });

    test('a Stop sits at its first member and keeps members in child order', () {
      // Step members el-c and el-a (listed reversed): the Stop replaces them
      // at el-a's position, its members stay in the scene's child order, so
      // z-order is stable. el-b keeps its own position.
      final spec = _spec(
        _scene(
          children: const [_title, _middle, _box],
          steps: const [
            {
              'elements': ['el-c', 'el-a'],
            },
          ],
        ),
      );
      final reference = [
        for (final child in spec.scenes.single.children) child.build(spec.anchors),
      ];
      final children = deckFromSpec(spec).scenes.single.children;
      expect(children, hasLength(2));
      final stop = children[0] as Stop;
      expect(stop.children, hasLength(2));
      expect(stop.children[0].runtimeType, reference[0].runtimeType); // el-a, a Text
      expect(stop.children[1].runtimeType, reference[2].runtimeType); // el-c, a Box
      expect(children[1].runtimeType, reference[1].runtimeType); // el-b keeps its slot
    });

    test('the steps list order wins over document position', () {
      final spec = _spec(
        _scene(
          children: const [_title, _middle],
          steps: const [
            {
              'elements': ['el-b'],
            },
            {
              'elements': ['el-a'],
            },
          ],
        ),
      );
      final deck = deckFromSpec(spec);
      final children = deck.scenes.single.children;
      // Positions follow the children list (el-a first), orders follow steps.
      expect((children[0] as Stop).order, 1);
      expect((children[1] as Stop).order, 0);
      final plan = compileSlidePlans(deck).single;
      expect(plan.stepCount, 3);
      expect(plan.steps[1].stops.single.order, 0);
      expect(plan.steps[2].stops.single.order, 1);
    });
  });

  group('notes become SpeakerNotes', () {
    test('scene notes lead the children as one SpeakerNotes', () {
      final spec = _spec(
        _scene(
          children: const [_title],
          notes: const {
            'text': 'Open with the outage story.',
            'highlights': ['3am page', 'one line fix'],
          },
        ),
      );
      final children = deckFromSpec(spec).scenes.single.children;
      expect(children, hasLength(2));
      final notes = children.first as SpeakerNotes;
      expect(notes.text, 'Open with the outage story.');
      expect(notes.highlights, ['3am page', 'one line fix']);
    });

    test('step notes ride inside their Stop', () {
      final spec = _spec(
        _scene(
          children: const [_title, _middle],
          steps: const [
            {
              'elements': ['el-b'],
              'notes': {'text': 'Land the punchline.'},
            },
          ],
        ),
      );
      final children = deckFromSpec(spec).scenes.single.children;
      final stop = children[1] as Stop;
      expect(stop.children, hasLength(2));
      final notes = stop.children.last as SpeakerNotes;
      expect(notes.text, 'Land the punchline.');
    });
  });

  group('anchor identity', () {
    test('a cross-element trigger on a base element resolves through spec.anchors', () {
      final spec = _spec(
        _scene(
          children: const [
            {
              'id': 'el-a',
              'type': 'Text',
              'text': 'A',
              'anchor': 'intro',
              'animate': [
                {'preset': 'fadeIn', 'duration': '30f'},
              ],
            },
            {
              'id': 'el-b',
              'type': 'Text',
              'text': 'B',
              'animate': [
                {
                  'preset': 'slideFadeIn',
                  'duration': '15f',
                  'at': {'kind': 'whenEnds', 'anchor': 'intro'},
                },
              ],
            },
          ],
        ),
      );
      final plan = compileSlidePlans(deckFromSpec(spec)).single;
      // el-b enters when el-a's 30 frames end and settles 15 frames later.
      expect(plan.steps.single.entranceFrames, 45);
    });
  });

  group('errors', () {
    test('an id naming no child is a StepCompileError', () {
      final spec = _spec(
        _scene(
          children: const [_title],
          steps: const [
            {
              'elements': ['el-ghost'],
            },
          ],
        ),
      );
      expect(
        () => deckFromSpec(spec),
        throwsA(
          isA<StepCompileError>().having(
            (error) => error.message,
            'message',
            contains('"el-ghost"'),
          ),
        ),
      );
    });

    test('an id in two steps is a StepCompileError', () {
      final spec = _spec(
        _scene(
          children: const [_title, _middle],
          steps: const [
            {
              'elements': ['el-a'],
            },
            {
              'elements': ['el-a'],
            },
          ],
        ),
      );
      expect(
        () => deckFromSpec(spec),
        throwsA(
          isA<StepCompileError>().having(
            (error) => error.message,
            'message',
            contains('at most one step'),
          ),
        ),
      );
    });

    test('an unknown theme token surfaces its FluvieSpecError, not a silent drop', () {
      final spec = _spec(
        _scene(
          children: const [
            {
              'id': 'el-a',
              'type': 'Box',
              'color': {'token': 'missing'},
            },
          ],
        ),
        top: const {
          'theme': {
            'palette': {'accent': '#FF6C5CE7'},
          },
        },
      );
      expect(
        () => deckFromSpec(spec),
        throwsA(
          isA<FluvieSpecError>().having((error) => error.message, 'message', contains('"missing"')),
        ),
      );
    });

    test('an id named twice by one step is a StepCompileError', () {
      final spec = _spec(
        _scene(
          children: const [_title],
          steps: const [
            {
              'elements': ['el-a', 'el-a'],
            },
          ],
        ),
      );
      expect(
        () => deckFromSpec(spec),
        throwsA(
          isA<StepCompileError>().having((error) => error.message, 'message', contains('twice')),
        ),
      );
    });
  });
}
