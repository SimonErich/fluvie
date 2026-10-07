import 'package:fluvie_ai/src/client/ai_client.dart';

/// One provider attempt, including its reply or transport error and duration.
typedef AiGenerationRecord = ({
  AiRequest request,
  AiResponse? response,
  Object? error,
  Duration elapsed,
});

/// Records generation evidence without changing a provider's request or reply.
/// Credentials and HTTP headers stay inside the wrapped client. [record] is
/// caller-owned; requests can contain private authored source and asset context.
final class RecordingAiClient implements AiClient {
  /// Wraps a provider and awaits [record] for each completed attempt.
  const RecordingAiClient({required this.client, required this.record});

  /// Provider transport owned by the caller.
  final AiClient client;

  /// Evidence sink. A failed sink prevents publication without its requested evidence.
  final Future<void> Function(AiGenerationRecord) record;

  @override
  bool get supportsStructuredOutput => client.supportsStructuredOutput;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    final watch = Stopwatch()..start();
    AiResponse? response;
    Object? failure;
    StackTrace? trace;
    try {
      response = await client.generate(request);
    } on Object catch (error, stack) {
      failure = error;
      trace = stack;
    }
    await record((request: request, response: response, error: failure, elapsed: watch.elapsed));
    if (failure != null) Error.throwWithStackTrace(failure, trace!);
    return response!;
  }
}
