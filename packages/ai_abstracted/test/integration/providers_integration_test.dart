@Tags(['generative'])
library;

import 'dart:io';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

/// Live provider checks. They are tagged `generative` and excluded from CI; run
/// them with the relevant API keys to verify the real wire shapes:
///
/// ```sh
/// dart test --tags generative
/// ```
///
/// Each test skips when its key is absent, so the file is safe to keep green.
void main() {
  final env = Platform.environment;
  // Opt-in twice: the explicit run flag AND the provider key, so a present key in
  // the environment never triggers an accidental paid API call.
  String? skipIf(String key) {
    if (env['FLUVIE_RUN_GENERATIVE_INTEGRATION'] == null) {
      return 'set FLUVIE_RUN_GENERATIVE_INTEGRATION=1 (and $key) to run';
    }
    return env[key] == null ? 'set $key to run' : null;
  }

  ProviderCredentials creds(String key) => ProviderCredentials(apiKey: env[key]!);
  const slow = Timeout(Duration(minutes: 5));

  test(
    'Flux image (BFL)',
    () async {
      final result = await FluxImageClient(credentials: creds('BFL_API_KEY')).generateImage(
        const ImageRequest(prompt: 'a tiny red square on white', width: 256, height: 256),
      );
      expect(result.bytes, isNotEmpty);
      expect(result.kind, MediaKind.image);
    },
    skip: skipIf('BFL_API_KEY'),
    timeout: slow,
  );

  test(
    'OpenAI image',
    () async {
      final result = await OpenAiImageClient(credentials: creds('OPENAI_API_KEY')).generateImage(
        const ImageRequest(prompt: 'a tiny red square on white', width: 256, height: 256),
      );
      expect(result.bytes, isNotEmpty);
    },
    skip: skipIf('OPENAI_API_KEY'),
    timeout: slow,
  );

  test(
    'Gemini image (Nano Banana)',
    () async {
      final result = await GeminiImageClient(credentials: creds('GEMINI_API_KEY')).generateImage(
        const ImageRequest(prompt: 'a tiny red square on white'),
      );
      expect(result.bytes, isNotEmpty);
    },
    skip: skipIf('GEMINI_API_KEY'),
    timeout: slow,
  );

  test(
    'Veo video (with audio)',
    () async {
      final result = await VeoVideoClient(credentials: creds('GEMINI_API_KEY')).generateVideo(
        const VideoRequest(prompt: 'a calm ocean wave at sunset', seconds: 4),
      );
      expect(result.bytes, isNotEmpty);
      expect(result.kind, MediaKind.video);
    },
    skip: skipIf('GEMINI_API_KEY'),
    timeout: slow,
  );

  test(
    'ElevenLabs speech',
    () async {
      final result = await ElevenLabsSpeechClient(
        credentials: creds('ELEVENLABS_API_KEY'),
      ).generateSpeech(const SpeechRequest(prompt: 'Welcome to Fluvie.'));
      expect(result.bytes, isNotEmpty);
      expect(result.kind, MediaKind.speech);
    },
    skip: skipIf('ELEVENLABS_API_KEY'),
    timeout: slow,
  );

  test(
    'ElevenLabs sound effect',
    () async {
      final result = await ElevenLabsSoundEffectClient(
        credentials: creds('ELEVENLABS_API_KEY'),
      ).generateSoundEffect(const SoundEffectRequest(prompt: 'a short whoosh', seconds: 1.5));
      expect(result.bytes, isNotEmpty);
    },
    skip: skipIf('ELEVENLABS_API_KEY'),
    timeout: slow,
  );

  test(
    'Suno music',
    () async {
      final result = await SunoMusicClient(credentials: creds('SUNO_API_KEY')).generateMusic(
        const MusicRequest(prompt: 'lofi hip hop, 90bpm', seconds: 10),
      );
      expect(result.bytes, isNotEmpty);
      expect(result.kind, MediaKind.music);
    },
    skip: skipIf('SUNO_API_KEY'),
    timeout: slow,
  );
}
