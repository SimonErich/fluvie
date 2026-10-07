part of 'deck_templates.dart';

/// The master starter: a blank deck whose single slide already adopts a
/// title-and-body master — every slot unfilled, ready for the fill flow.
final DeckTemplate _starterTemplate = DeckTemplate(
  id: 'starter',
  name: 'Master starter',
  purpose: 'Start clean',
  description: 'One master, empty slots, nothing else',
  deck: {
    'fluvieSpec': 1,
    'size': 'hd',
    'fps': 30,
    'theme': builtinThemes['midnight'],
    'masters': {
      'base': {
        'background': {
          'kind': 'color',
          'color': {'token': 'background'},
        },
        'layout': 'canvas',
        'children': [
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.22, 'w': 0.8, 'h': 0.18},
            'style': {
              'token': 'title',
              'color': {'token': 'text'},
            },
          },
          {
            'type': 'Placeholder',
            'slot': 'body',
            'transform': {'x': 0.5, 'y': 0.6, 'w': 0.8, 'h': 0.5},
            'style': {
              'token': 'body',
              'color': {'token': 'text'},
            },
          },
        ],
      },
    },
    'scenes': [
      {'duration': '5s', 'layout': 'canvas', 'master': 'base'},
    ],
  },
);
