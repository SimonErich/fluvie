# ai_abstracted

One set of contracts for generative AI across providers and mediums.

`ai_abstracted` normalizes text, image, video, speech, sound-effect, and music
generation behind small, uniform capability interfaces. You pick a capability
(for example `ImageGenerator`), hand it a typed request plus credentials, and get
back bytes with normalized metadata — regardless of whether the bytes came from
Flux, Gemini, OpenAI, Veo, ElevenLabs, or Suno.

It is pure Dart (no Flutter, no `dart:io`), so it runs on servers, the VM, and
the web. It never writes files: callers decide how to cache results.

```dart
import 'package:ai_abstracted/ai_abstracted.dart';

Future<void> main() async {
  final images = FluxImageClient(
    credentials: const ProviderCredentials(apiKey: 'bfl-...'),
  );
  final result = await images.generateImage(
    const ImageRequest(prompt: 'a neon skyline at dusk', width: 1024, height: 1024),
  );
  // result.bytes, result.mimeType, result.metadata.width/height
}
```

## Capabilities

`TextGenerator`, `ImageGenerator`, `VideoGenerator`, `SpeechGenerator`,
`SoundEffectGenerator`, `MusicGenerator`. Every contract is a single async method
that takes a typed request and an optional progress callback.

## Providers

Google Gemini (text + image), Google Veo (video, including Veo 3 audio), OpenAI
(image), Black Forest Labs Flux (image), ElevenLabs (speech + sound effects), and
Suno via sunoapi.org (music). Adding a provider is one thin client over the shared
transport.

## Testing

Every capability has an in-memory fake (`FakeImageGenerator`, …) that returns
fixture bytes, so downstream code is testable without a network or API keys.
