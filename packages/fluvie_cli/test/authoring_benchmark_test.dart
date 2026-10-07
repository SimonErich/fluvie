@Tags(['ffmpeg'])
library;

import 'dart:io';

import 'package:fluvie_cli/src/authoring_benchmark.dart';
import 'package:test/test.dart';

void main() {
  test('benchmark distinguishes rendering, preservation and unmeasured visual quality', () async {
    final root = await Directory.systemTemp.createTemp('fluvie_benchmark_test_');
    addTearDown(() => root.delete(recursive: true));
    final report = await runAuthoringBenchmark(
      suite: {
        'schemaVersion': 1,
        'cases': [
          {
            'id': 'preserve',
            'action': 'edit',
            'prompt': 'Change the title',
            'preserve': ['custom badge'],
          },
          {'id': 'fail', 'action': 'generate', 'prompt': 'Create a video'},
        ],
      },
      output: root,
      provider: 'fake',
      model: 'fixture',
      realProvider: false,
      execute: (task, directory) async {
        if (task['id'] == 'fail') throw StateError('provider rejected this request');
        return {
          'ok': true,
          'beforeSource': 'custom badge',
          'afterSource': 'changed title',
          'renderVerified': true,
        };
      },
    );
    expect(report['ok'], isFalse);
    expect(report['realProvider'], isFalse);
    final cases = (report['cases']! as List).cast<Map<String, Object?>>();
    expect(cases.first['preserved'], isFalse);
    expect(cases.first['visualQuality'], 'requires_human_review');
    expect(cases.last['error'], contains('provider rejected'));
    expect(File('${root.path}/preserve/prompt.txt').existsSync(), isTrue);
    expect(File('${root.path}/benchmark.json').existsSync(), isTrue);
  });
}
