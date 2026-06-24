import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:ai_abstracted/src/transport/poller.dart';
import 'package:test/test.dart';

void main() {
  final slept = <Duration>[];
  Future<void> recordSleep(Duration d) async => slept.add(d);

  setUp(slept.clear);

  group('pollUntil', () {
    test('returns the first non-null poll result', () async {
      var calls = 0;
      final result = await pollUntil<String>(
        poll: () async {
          calls++;
          return calls >= 3 ? 'ready' : null;
        },
        interval: const Duration(seconds: 1),
        timeout: const Duration(seconds: 60),
        sleep: recordSleep,
      );
      expect(result, 'ready');
      expect(calls, 3);
      expect(slept.length, 2);
      expect(slept.every((d) => d == const Duration(seconds: 1)), isTrue);
    });

    test('emits queued then running progress while polling', () async {
      final stages = <GenerationStage>[];
      var calls = 0;
      await pollUntil<int>(
        poll: () async {
          calls++;
          return calls >= 2 ? calls : null;
        },
        interval: const Duration(seconds: 1),
        timeout: const Duration(seconds: 60),
        onProgress: (p) => stages.add(p.stage),
        sleep: recordSleep,
      );
      expect(stages, isNotEmpty);
      expect(stages.first, GenerationStage.queued);
      expect(stages, contains(GenerationStage.running));
    });

    test('throws AiTimeoutException once elapsed exceeds timeout', () async {
      var nowMs = 0;
      DateTime fakeNow() => DateTime.fromMillisecondsSinceEpoch(nowMs);
      await expectLater(
        pollUntil<int>(
          poll: () async {
            nowMs += 1000;
            return null;
          },
          interval: const Duration(seconds: 1),
          timeout: const Duration(seconds: 3),
          sleep: recordSleep,
          now: fakeNow,
        ),
        throwsA(isA<AiTimeoutException>()),
      );
    });

    test('does not sleep when the first poll already succeeds', () async {
      final result = await pollUntil<String>(
        poll: () async => 'done',
        interval: const Duration(seconds: 1),
        timeout: const Duration(seconds: 60),
        sleep: recordSleep,
      );
      expect(result, 'done');
      expect(slept, isEmpty);
    });
  });
}
