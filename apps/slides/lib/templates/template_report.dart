part of 'deck_templates.dart';

/// The report template: one section master over the paper theme.
final DeckTemplate _reportTemplate = DeckTemplate(
  id: 'report',
  name: 'Status report',
  purpose: 'Report',
  description: 'Sections with a headline and findings',
  deck: {
    'fluvieSpec': 1,
    'size': 'hd',
    'fps': 30,
    'theme': builtinThemes['paper'],
    'masters': {
      'section': {
        'background': {
          'kind': 'color',
          'color': {'token': 'background'},
        },
        'layout': 'canvas',
        'children': [
          {
            'type': 'Box',
            'color': {'token': 'accent'},
            'transform': {'x': 0.5, 'y': 0.095, 'w': 1.0, 'h': 0.012},
          },
          {
            'type': 'Placeholder',
            'slot': 'title',
            'transform': {'x': 0.5, 'y': 0.2, 'w': 0.84, 'h': 0.12},
            'style': {
              'token': 'heading',
              'color': {'token': 'text'},
            },
          },
          {
            'type': 'Placeholder',
            'slot': 'body',
            'transform': {'x': 0.5, 'y': 0.58, 'w': 0.84, 'h': 0.55},
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
        'master': 'section',
        'fills': {
          'title': {'type': 'Text', 'text': 'Quarterly report'},
          'body': {'type': 'Text', 'text': 'The quarter in one page'},
        },
      },
      {
        'duration': '5s',
        'layout': 'canvas',
        'master': 'section',
        'fills': {
          'title': {'type': 'Text', 'text': 'Findings'},
          'body': {'type': 'Text', 'text': 'What moved, what stalled, what surprised us'},
        },
      },
    ],
  },
);
