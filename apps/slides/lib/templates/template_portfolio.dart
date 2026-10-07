part of 'deck_templates.dart';

/// The portfolio template: a showcase master with a media slot over the
/// neon theme — the media slot stays unfilled, inviting the fill flow.
final DeckTemplate _portfolioTemplate = DeckTemplate(
  id: 'portfolio',
  name: 'Portfolio',
  purpose: 'Portfolio',
  description: 'A showcase slide per piece of work',
  deck: {
    'fluvieSpec': 1,
    'size': 'hd',
    'fps': 30,
    'theme': builtinThemes['neon'],
    'masters': {
      'showcase': {
        'background': {
          'kind': 'color',
          'color': {'token': 'background'},
        },
        'layout': 'canvas',
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.12, 'w': 0.84, 'h': 0.1},
            'style': {
              'token': 'heading',
              'color': {'token': 'accent'},
            },
          },
          {
            'type': 'Placeholder',
            'slot': 'media',
            'transform': {'x': 0.5, 'y': 0.58, 'w': 0.72, 'h': 0.6},
          },
        ],
      },
    },
    'scenes': [
      {
        'duration': '5s',
        'layout': 'canvas',
        'master': 'showcase',
        'fills': {
          'title': {'type': 'Text', 'text': 'Selected work'},
        },
      },
    ],
  },
);
