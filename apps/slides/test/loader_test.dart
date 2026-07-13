import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:slides/loader/open_fluvie_file.dart';

const Map<String, Object?> _spec = {
  'fluvieSpec': 1,
  'size': 'hd',
  'fps': 30,
  'scenes': [
    {
      'duration': '90f',
      'children': [
        {
          'type': 'Text',
          'text': 'Hello from a file',
          'style': {'color': '#FFFFFF', 'fontSize': 72},
          'animate': [
            {'preset': 'fadeIn', 'duration': '30f'},
          ],
        },
      ],
    },
  ],
};

void main() {
  test('a valid .fluvie document becomes a presentable deck', () {
    final loaded = parseFluvieJson('demo.fluvie', jsonEncode(_spec));
    expect(loaded.error, isNull);
    expect(loaded.video, isNotNull);
    expect(loaded.video!.scenes, hasLength(1));
    expect(loaded.rawJson, isNotNull);
  });

  test('broken JSON fails with a friendly message', () {
    final loaded = parseFluvieJson('demo.fluvie', '{not json');
    expect(loaded.video, isNull);
    expect(loaded.error, contains('not valid JSON'));
  });

  test('a JSON array is rejected: one object per file', () {
    final loaded = parseFluvieJson('demo.fluvie', '[]');
    expect(loaded.error, 'A .fluvie file holds one JSON object.');
  });

  test('a spec problem surfaces the resolver message', () {
    final loaded = parseFluvieJson('demo.fluvie', '{"scenes": []}');
    expect(loaded.video, isNull);
    expect(loaded.error, contains('did not resolve'));
  });
}
