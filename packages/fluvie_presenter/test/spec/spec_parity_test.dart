import 'package:flutter/widgets.dart' hide Animation;
import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_presenter/fluvie_presenter.dart';

/// The spec twin of [_widgetDeck]: the same deck as data, with steps and
/// notes in the scene instead of Stop/SpeakerNotes widgets.
final Map<String, Object?> _specDocument = {
  'fluvieSpec': 1,
  'size': {'width': 640, 'height': 360},
  'fps': 30,
  'scenes': [
    {
      'duration': '4s',
      'children': [
        {
          'id': 'el-title',
          'type': 'Text',
          'text': 'Incident review',
          'anchor': 'intro',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
        {
          'id': 'el-kicker',
          'type': 'Text',
          'text': 'What 3am taught us',
          'animate': [
            {
              'preset': 'slideFadeIn',
              'duration': '15f',
              'at': {'kind': 'whenEnds', 'anchor': 'intro'},
            },
          ],
        },
        {
          'id': 'el-b1',
          'type': 'Text',
          'text': '3am page',
          'animate': [
            {'preset': 'slideFadeIn', 'duration': '20f'},
          ],
        },
        {
          'id': 'el-b2',
          'type': 'Text',
          'text': 'one line fix',
          'animate': [
            {'preset': 'fadeIn', 'delay': '10f', 'duration': '20f'},
          ],
        },
      ],
      'steps': [
        {
          'elements': ['el-b1'],
        },
        {
          'elements': ['el-b2'],
          'notes': {
            'text': 'Land the punchline.',
            'highlights': ['fix'],
          },
        },
      ],
      'notes': {
        'text': 'Open with the outage story.',
        'highlights': ['3am page', 'one line fix'],
      },
    },
    {
      'duration': '2s',
      'children': [
        {
          'id': 'el-x',
          'type': 'Text',
          'text': 'Thanks',
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
      'steps': [
        {
          'elements': ['el-x'],
        },
      ],
    },
  ],
};

/// The widget-authored deck: what a hand would write with Stop and
/// SpeakerNotes for the same presentation.
Video _widgetDeck() {
  final intro = Anchor('intro');
  return Video(
    size: const VideoSize(640, 360),
    scenes: [
      Scene(
        duration: const Time.seconds(4),
        children: [
          const SpeakerNotes(
            text: 'Open with the outage story.',
            highlights: ['3am page', 'one line fix'],
          ),
          const Text(
            'Incident review',
          ).animate([Animation.fadeIn(duration: const Time.frames(30))], anchor: intro),
          const Text('What 3am taught us').animate([
            Animation.slideFadeIn(duration: const Time.frames(15), at: Trigger.whenEnds(intro)),
          ]),
          Stop(
            children: [
              const Text(
                '3am page',
              ).animate([Animation.slideFadeIn(duration: const Time.frames(20))]),
            ],
          ),
          Stop(
            children: [
              const Text('one line fix').animate([
                Animation.fadeIn(delay: const Time.frames(10), duration: const Time.frames(20)),
              ]),
              const SpeakerNotes(text: 'Land the punchline.', highlights: ['fix']),
            ],
          ),
        ],
      ),
      Scene(
        duration: const Time.seconds(2),
        children: [
          Stop(
            children: [
              const Text('Thanks').animate([Animation.fadeIn(duration: const Time.frames(30))]),
            ],
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('the spec twin compiles to the same slide plans as the widget deck', () {
    final widgetDeck = _widgetDeck();
    final widgetPlans = compileSlidePlans(widgetDeck);
    final specDeck = deckFromSpec(VideoSpec.fromJson(_specDocument));
    final specPlans = compileSlidePlans(specDeck);

    expect(specPlans, hasLength(widgetPlans.length));
    for (var s = 0; s < widgetPlans.length; s++) {
      expect(specPlans[s].sceneIndex, widgetPlans[s].sceneIndex);
      expect(specPlans[s].stepCount, widgetPlans[s].stepCount, reason: 'scene $s step count');
      for (var k = 0; k < widgetPlans[s].steps.length; k++) {
        expect(specPlans[s].steps[k].index, widgetPlans[s].steps[k].index);
        expect(specPlans[s].steps[k].stops, hasLength(widgetPlans[s].steps[k].stops.length));
        expect(
          specPlans[s].steps[k].entranceFrames,
          widgetPlans[s].steps[k].entranceFrames,
          reason: 'scene $s step $k settle',
        );
      }
    }
  });

  test('the spec twin compiles to the same speaker notes as the widget deck', () {
    final widgetDeck = _widgetDeck();
    final widgetNotes = compileNotes(widgetDeck, compileSlidePlans(widgetDeck));
    // The same Video instance must feed both compiles: plans key stops by
    // widget identity.
    final specDeck = deckFromSpec(VideoSpec.fromJson(_specDocument));
    final specNotes = compileNotes(specDeck, compileSlidePlans(specDeck));

    expect(specNotes, hasLength(widgetNotes.length));
    for (var s = 0; s < widgetNotes.length; s++) {
      expect(specNotes[s], hasLength(widgetNotes[s].length));
      for (var k = 0; k < widgetNotes[s].length; k++) {
        expect(specNotes[s][k].text, widgetNotes[s][k].text, reason: 'scene $s step $k text');
        expect(
          specNotes[s][k].highlights,
          widgetNotes[s][k].highlights,
          reason: 'scene $s step $k highlights',
        );
      }
    }
  });

  test('the merge rule lands as authored: replace text, append highlights', () {
    final deck = deckFromSpec(VideoSpec.fromJson(_specDocument));
    final notes = compileNotes(deck, compileSlidePlans(deck));
    expect(notes[0][0].text, 'Open with the outage story.');
    expect(notes[0][0].highlights, ['3am page', 'one line fix']);
    expect(notes[0][1].text, 'Open with the outage story.');
    expect(notes[0][2].text, 'Land the punchline.');
    expect(notes[0][2].highlights, ['3am page', 'one line fix', 'fix']);
    expect(notes[1][0].text, isNull);
    expect(notes[1][1].highlights, isEmpty);
  });
}
