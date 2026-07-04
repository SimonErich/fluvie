import 'package:fluvie_ai/src/client/ai_client.dart';

/// A scripted [AiClient] for tests: returns queued replies in order and records
/// the requests it received.
///
/// Queue "bad then good" replies to exercise the author service's repair loop
/// without any network.
class FakeAiClient implements AiClient {
  /// Creates a fake that replies with [replies] in order.
  FakeAiClient(this.replies, {this.supportsStructuredOutput = true});

  /// The replies to return, in order.
  final List<String> replies;

  @override
  final bool supportsStructuredOutput;

  /// The requests this client has received, in order, for assertions.
  final List<AiRequest> requests = [];

  int _index = 0;

  @override
  Future<AiResponse> generate(AiRequest request) async {
    requests.add(request);
    if (_index >= replies.length) {
      throw AiClientException('FakeAiClient ran out of scripted replies');
    }
    return AiResponse(replies[_index++]);
  }
}
