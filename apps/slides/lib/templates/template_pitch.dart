part of 'deck_templates.dart';

/// The pitch template: a cover master and a content master over the
/// midnight theme, every style bound to the shared token vocabulary.
final DeckTemplate _pitchTemplate = DeckTemplate(
  id: 'pitch',
  name: 'Pitch deck',
  purpose: 'Pitch',
  description: 'A cover, the problem, and the ask',
  deck: {
    'fluvieSpec': 1,
    'size': 'hd',
    'fps': 30,
    'theme': builtinThemes['midnight'],
    'masters': {
      'cover': {
        'background': {
          'kind': 'color',
          'color': {'token': 'background'},
        },
        'layout': 'canvas',
        'children': [
          {
            'type': 'Box',
            'color': {'token': 'accent'},
            'transform': {'x': 0.5, 'y': 0.74, 'w': 0.24, 'h': 0.008},
          },
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.44, 'w': 0.8, 'h': 0.2},
            'style': {
              'token': 'title',
              'color': {'token': 'text'},
            },
          },
          {
            'type': 'Placeholder',
            'slot': 'subtitle',
            'transform': {'x': 0.5, 'y': 0.62, 'w': 0.7, 'h': 0.1},
            'style': {
              'token': 'body',
              'color': {'token': 'muted'},
            },
          },
        ],
      },
      'content': {
        'background': {
          'kind': 'color',
          'color': {'token': 'background'},
        },
        'layout': 'canvas',
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.18, 'w': 0.84, 'h': 0.14},
            'style': {
              'token': 'heading',
              'color': {'token': 'text'},
            },
          },
          {
            'type': 'Placeholder',
            'slot': 'body',
            'transform': {'x': 0.5, 'y': 0.56, 'w': 0.84, 'h': 0.5},
            'style': {
              'token': 'body',
              'color': {'token': 'text'},
            },
          },
        ],
      },
    },
    'scenes': [
      {
        'duration': '5s',
        'layout': 'canvas',
        'master': 'cover',
        'fills': {
          'title': {'type': 'Text', 'text': 'Your big idea'},
          'subtitle': {'type': 'Text', 'text': 'Why now, and why you'},
        },
      },
      {
        'duration': '5s',
        'layout': 'canvas',
        'master': 'content',
        'fills': {
          'title': {'type': 'Text', 'text': 'The problem'},
          'body': {'type': 'Text', 'text': 'What hurts today, and what it costs'},
        },
      },
      {
        'duration': '5s',
        'layout': 'canvas',
        'master': 'content',
        'fills': {
          'title': {'type': 'Text', 'text': 'The ask'},
          'body': {'type': 'Text', 'text': 'What you need to build it'},
        },
      },
    ],
  },
);
