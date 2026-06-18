import 'package:fluvie_ai/src/author/video_author_service.dart';
import 'package:fluvie_ai/src/client/ai_client.dart';
import 'package:riverpod/riverpod.dart';

/// The active [AiClient]. It has no default: override it with a concrete
/// provider (Claude, Gemini, Mistral, Ollama) or a fake in tests.
final aiClientProvider = Provider<AiClient>((ref) {
  throw UnimplementedError(
    'Override aiClientProvider with a concrete AiClient '
    '(Claude, Gemini, Mistral, Ollama) or a fake in tests.',
  );
});

/// The [VideoAuthorService], built on the active [aiClientProvider].
final videoAuthorServiceProvider = Provider<VideoAuthorService>(
  (ref) => LlmVideoAuthorService(client: ref.watch(aiClientProvider)),
);
