import 'package:fluvie_cli/src/codegen/dart_spec_printer.dart';
import 'package:test/test.dart';

void main() {
  test('clip transition print emits readable native widgets and quoted source data', () {
    final code = printVideoSpecJson({
      'fluvieSpec': 1,
      'fps': 30,
      'scenes': [
        {
          'duration': '120f',
          'children': [
            for (final id in ['a', 'b'])
              {
                'id': id,
                'type': 'Clip',
                'source': {'kind': 'asset', 'value': "clip\u0024id'.mp4"},
              },
          ],
          'transitions': [
            {
              'between': ['a', 'b'],
              'kind': 'crossFade',
              'duration': '10f',
            },
          ],
        },
      ],
    });
    expect(code, isNot(contains('VideoSpec.fromJson(')));
    expect(code, contains('ClipTransitionGroup('));
    expect(code, contains("ElementId(id: 'a'"));
    expect(code, contains("outgoing: 'a'"));
    expect(code, contains("incoming: 'b'"));
    expect(code, contains('Transition.crossFade(10.frames)'));
    expect(code, contains(r"clip\$id\'.mp4"));
    expect(code, contains('Clip.asset('));
  });
  test('native clip policy preserves lane gain, fades and automation without JSON fallback', () {
    final code = printVideoSpecJson({
      'fluvieSpec': 1,
      'lanes': [
        {'id': 'v1', 'gain': 0.5},
        {'id': 'muted', 'muted': true},
      ],
      'scenes': [
        {
          'duration': '3s',
          'children': [
            {
              'type': 'Clip',
              'lane': 'v1',
              'id': 'cat',
              'source': {'kind': 'asset', 'value': 'cat.mov'},
              'volume': 0.8,
              'fadeIn': '10f',
              'automation': {
                'volume': {
                  'values': [0.2, 0.8],
                  'positions': ['0f', '90f'],
                },
              },
            },
            {
              'type': 'Clip',
              'lane': 'muted',
              'source': {'kind': 'asset', 'value': 'silent.webm'},
            },
          ],
        },
      ],
    });
    expect(code, isNot(contains('VideoSpec.fromJson')));
    expect(code, contains('.scaledBy(0.5)'));
    expect(code, contains('ClipAudio.muted()'));
    expect(code, contains('AudioAutomation('));
    expect(code, contains("lane: 'v1'"));
  });
}
