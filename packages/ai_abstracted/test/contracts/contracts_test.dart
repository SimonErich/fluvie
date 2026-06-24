import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

GenerationResult _result(MediaKind kind) => GenerationResult(
  bytes: Uint8List(0),
  mimeType: 'application/octet-stream',
  kind: kind,
  metadata: const GenerationMetadata(model: 'stub'),
);

class _Image implements ImageGenerator {
  @override
  Future<GenerationResult> generateImage(
    ImageRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.image);
}

class _Video implements VideoGenerator {
  @override
  Future<GenerationResult> generateVideo(
    VideoRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.video);
}

class _Speech implements SpeechGenerator {
  @override
  Future<GenerationResult> generateSpeech(
    SpeechRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.speech);
}

class _Sound implements SoundEffectGenerator {
  @override
  Future<GenerationResult> generateSoundEffect(
    SoundEffectRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.soundEffect);
}

class _Music implements MusicGenerator {
  @override
  Future<GenerationResult> generateMusic(
    MusicRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.music);
}

class _Text implements TextGenerator {
  @override
  Future<GenerationResult> generateText(
    TextRequest request, {
    void Function(GenerationProgress)? onProgress,
  }) async => _result(MediaKind.text);
}

void main() {
  test('each contract is implementable and returns its kind', () async {
    expect((await _Image().generateImage(const ImageRequest(prompt: 'x'))).kind, MediaKind.image);
    expect((await _Video().generateVideo(const VideoRequest(prompt: 'x'))).kind, MediaKind.video);
    expect(
      (await _Speech().generateSpeech(const SpeechRequest(prompt: 'x'))).kind,
      MediaKind.speech,
    );
    expect(
      (await _Sound().generateSoundEffect(const SoundEffectRequest(prompt: 'x'))).kind,
      MediaKind.soundEffect,
    );
    expect((await _Music().generateMusic(const MusicRequest(prompt: 'x'))).kind, MediaKind.music);
    expect((await _Text().generateText(const TextRequest(prompt: 'x'))).kind, MediaKind.text);
  });
}
