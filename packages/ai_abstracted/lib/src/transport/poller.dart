import 'package:ai_abstracted/src/core/ai_exception.dart';
import 'package:ai_abstracted/src/core/generation_progress.dart';

/// Polls [poll] every [interval] until it returns a non-null result.
///
/// Emits a [GenerationStage.queued] update before the first poll and a
/// [GenerationStage.running] update before each later poll, through [onProgress]
/// when given. Sleeps [interval] between polls via the injected [sleep] and
/// reads the clock via [now], so tests run instantly and deterministically.
/// Throws an [AiTimeoutException] (labelled [provider]) once the elapsed time
/// exceeds [timeout].
Future<R> pollUntil<R>({
  required Future<R?> Function() poll,
  required Duration interval,
  required Duration timeout,
  void Function(GenerationProgress)? onProgress,
  Future<void> Function(Duration) sleep = Future.delayed,
  DateTime Function() now = DateTime.now,
  String provider = 'poller',
}) async {
  final start = now();
  var first = true;
  while (true) {
    onProgress?.call(
      GenerationProgress(stage: first ? GenerationStage.queued : GenerationStage.running),
    );
    first = false;

    final result = await poll();
    if (result != null) {
      return result;
    }

    if (now().difference(start) > timeout) {
      throw AiTimeoutException(
        'Polling exceeded ${timeout.inSeconds}s',
        provider: provider,
      );
    }
    await sleep(interval);
  }
}
