/// Author Fluvie videos from natural language.
///
/// A provider-agnostic `AiClient` turns a prompt into a deterministic
/// `VideoSpec` (from `package:fluvie`) through a `VideoAuthorService`. The model
/// runs only at authoring time; rendering the resulting spec never calls a
/// model. Concrete clients for Claude, Gemini, Mistral, and Ollama live under
/// this barrel, alongside a `FakeAiClient` for tests.
library;

export 'src/author/ai_providers.dart';
export 'src/author/prompting.dart' show buildAuthorSystemPrompt;
export 'src/author/video_author_service.dart';
export 'src/client/ai_client.dart';
export 'src/client/ai_client_factory.dart' show aiClientFromEnv;
export 'src/client/claude_ai_client.dart' show ClaudeAiClient;
export 'src/client/fake_ai_client.dart' show FakeAiClient;
export 'src/client/gemini_ai_client.dart' show GeminiAiClient;
export 'src/client/mistral_ai_client.dart' show MistralAiClient;
export 'src/client/ollama_ai_client.dart' show OllamaAiClient;
