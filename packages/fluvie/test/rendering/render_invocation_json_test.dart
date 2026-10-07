import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/rendering.dart';

void main() {
  test('worker invocation preserves runtime render and review settings', () {
    final invocation = RenderInvocation.fromJson({
      'outputDir': '/tmp/result',
      'projectDir': '/tmp/project',
      'operation': 'review',
      'frameIndex': 7,
      'frameCount': 30,
      'compositionFingerprint': 'abc',
      'aspect': 'reels',
      'quality': 'low',
      'format': 'mp4',
      'reviewFrames': [0, 7, 29],
      'reviewDeterminism': true,
    });
    expect(invocation.operation, 'review');
    expect(invocation.frameCount, 30);
    expect(invocation.reviewFrames, [0, 7, 29]);
    expect(invocation.reviewDeterminism, isTrue);
    expect(invocation.aspect, isNotNull);
  });

  test('worker invocation rejects ambiguous or malformed requests', () {
    for (final value in <Map<String, Object?>>[
      {},
      {'outputDir': '/tmp/result', 'operation': 'exec'},
      {'outputDir': '/tmp/result', 'frameIndex': -1},
      {'outputDir': '/tmp/result', 'frameCount': 0},
      {
        'outputDir': '/tmp/result',
        'reviewFrames': ['1'],
      },
      {'outputDir': '/tmp/result', 'aspect': 'unknown'},
      {'outputDir': '/tmp/result', 'surprise': true},
    ]) {
      expect(() => RenderInvocation.fromJson(value), throwsArgumentError);
    }
  });
}
