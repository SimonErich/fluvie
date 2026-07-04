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
export 'src/client/gemini_ai_client.dart' show GeminiAiClient;
export 'src/client/mistral_ai_client.dart' show MistralAiClient;
export 'src/client/ollama_ai_client.dart' show OllamaAiClient;
export 'src/fake/fake_ai_client.dart' show FakeAiClient;
export 'src/generative/widgets/generative_image.dart';
export 'src/generative/widgets/generative_music.dart';
export 'src/generative/widgets/generative_sound_fx.dart';
export 'src/generative/widgets/generative_speech.dart';
export 'src/generative/widgets/generative_video.dart';
