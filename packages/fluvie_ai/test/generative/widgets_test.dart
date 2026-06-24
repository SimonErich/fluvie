import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/fluvie.dart';
import 'package:fluvie_ai/fluvie_ai.dart';

void main() {
  group('GenerativeImage', () {
    test('flux builds an image GenerativeMedia with prompt, seed, and size', () {
      final media = GenerativeImage.flux(prompt: 'a cat', seed: 'z', width: 512, height: 512);
      expect(media, isA<GenerativeMedia>());
      expect(media.source.kind, GenerativeKind.image);
      expect(media.source.providerId, 'flux');
      expect(media.source.seed, 'z');
      expect(media.source.params['width'], 512);
      expect(media.source.params['height'], 512);
    });

    test('gemini and openai set their provider', () {
      expect(GenerativeImage.gemini(prompt: 'x').source.providerId, 'gemini');
      expect(GenerativeImage.openai(prompt: 'x').source.providerId, 'openai');
    });
  });

  group('GenerativeVideo.veo', () {
    test('builds a video GenerativeMedia carrying its seconds and audio policy', () {
      final media = GenerativeVideo.veo(prompt: 'a walk', seconds: 6);
      expect(media.source.kind, GenerativeKind.video);
      expect(media.source.providerId, 'veo');
      expect(media.source.params['seconds'], 6);
      expect(media.audio.muted, isFalse);
    });

    test('withAudio: false mutes the embedded track', () {
      expect(GenerativeVideo.veo(prompt: 'x', withAudio: false).audio.muted, isTrue);
    });
  });

  group('GenerativeAudio sugar', () {
    test('music (suno) builds a music GenerativeAudio', () {
      final audio = GenerativeMusic.suno(prompt: 'lofi', seconds: 10, volume: 0.6);
      expect(audio, isA<GenerativeAudio>());
      expect(audio.source.kind, GenerativeKind.music);
      expect(audio.source.providerId, 'suno');
      expect(audio.volume, 0.6);
    });

    test('speech (eleven) uses the text as the prompt and carries the voice', () {
      final audio = GenerativeSpeech.eleven(text: 'hello there', voice: 'rachel');
      expect(audio.source.kind, GenerativeKind.speech);
      expect(audio.source.providerId, 'elevenlabs');
      expect(audio.source.prompt, 'hello there');
      expect(audio.source.params['voice'], 'rachel');
    });

    test('sound effect (eleven) builds a soundEffect GenerativeAudio', () {
      final audio = GenerativeSoundFx.eleven(prompt: 'whoosh', seconds: 1.5);
      expect(audio.source.kind, GenerativeKind.soundEffect);
      expect(audio.source.providerId, 'elevenlabs');
      expect(audio.source.params['seconds'], 1.5);
    });
  });
}
