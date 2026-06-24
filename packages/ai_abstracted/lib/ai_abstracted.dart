/// Provider-agnostic generative AI: one set of contracts for text, image,
/// video, speech, sound-effect, and music generation across many providers.
///
/// Import this barrel and nothing else:
///
/// ```dart
/// import 'package:ai_abstracted/ai_abstracted.dart';
/// ```
library;

export 'src/config/credentials_from_env.dart';
export 'src/config/provider_credentials.dart';
export 'src/contracts/image_generator.dart';
export 'src/contracts/music_generator.dart';
export 'src/contracts/sound_effect_generator.dart';
export 'src/contracts/speech_generator.dart';
export 'src/contracts/text_generator.dart';
export 'src/contracts/video_generator.dart';
export 'src/core/ai_exception.dart';
export 'src/core/generation_metadata.dart';
export 'src/core/generation_progress.dart';
export 'src/core/generation_request.dart';
export 'src/core/generation_result.dart';
export 'src/core/media_kind.dart';
export 'src/core/requests/image_request.dart';
export 'src/core/requests/music_request.dart';
export 'src/core/requests/sound_effect_request.dart';
export 'src/core/requests/speech_request.dart';
export 'src/core/requests/text_request.dart';
export 'src/core/requests/video_request.dart';
export 'src/core/text_image.dart';
export 'src/core/text_message.dart';
export 'src/fake/fake_image_generator.dart';
export 'src/fake/fake_music_generator.dart';
export 'src/fake/fake_sound_effect_generator.dart';
export 'src/fake/fake_speech_generator.dart';
export 'src/fake/fake_text_generator.dart';
export 'src/fake/fake_video_generator.dart';
export 'src/providers/anthropic/claude_text_client.dart';
export 'src/providers/bfl/flux_image_client.dart';
export 'src/providers/elevenlabs/elevenlabs_sound_effect_client.dart';
export 'src/providers/elevenlabs/elevenlabs_speech_client.dart';
export 'src/providers/google/gemini_image_client.dart';
export 'src/providers/google/gemini_text_client.dart';
export 'src/providers/google/veo_video_client.dart';
export 'src/providers/mistral/mistral_text_client.dart';
export 'src/providers/ollama/ollama_text_client.dart';
export 'src/providers/openai/openai_image_client.dart';
export 'src/providers/suno/suno_music_client.dart';
export 'src/registry/provider_id.dart';
export 'src/registry/provider_registry.dart';
export 'src/transport/retry_policy.dart';
