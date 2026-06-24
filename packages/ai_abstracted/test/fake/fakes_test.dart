import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_abstracted/ai_abstracted.dart';
import 'package:test/test.dart';

List<GenerationStage> _stages() => <GenerationStage>[];

void main() {
  group('FakeImageGenerator', () {
    test('returns image bytes, records the request, and emits lifecycle', () async {
      final stages = _stages();
      final fake = FakeImageGenerator();
      const request = ImageRequest(prompt: 'a cat');
      final result = await fake.generateImage(request, onProgress: (p) => stages.add(p.stage));
      expect(result.kind, MediaKind.image);
      expect(result.bytes, isNotEmpty);
      expect(result.mimeType, 'image/png');
      expect(fake.lastRequest, same(request));
      expect(stages, [GenerationStage.queued, GenerationStage.running, GenerationStage.done]);
    });

    test('honors custom fixture bytes and metadata', () async {
      final bytes = Uint8List.fromList([9, 8, 7]);
      const meta = GenerationMetadata(model: 'custom', width: 4, height: 2);
      final fake = FakeImageGenerator(bytes: bytes, metadata: meta);
      final result = await fake.generateImage(const ImageRequest(prompt: 'x'));
      expect(result.bytes, bytes);
      expect(result.metadata.model, 'custom');
      expect(result.metadata.width, 4);
    });
  });

  test('FakeVideoGenerator returns video bytes with audio metadata', () async {
    final stages = _stages();
    final fake = FakeVideoGenerator();
    final result = await fake.generateVideo(
      const VideoRequest(prompt: 'x'),
      onProgress: (p) => stages.add(p.stage),
    );
    expect(result.kind, MediaKind.video);
    expect(result.mimeType, 'video/mp4');
    expect(result.metadata.hasAudio, isTrue);
    expect(fake.lastRequest, isNotNull);
    expect(stages, [GenerationStage.queued, GenerationStage.running, GenerationStage.done]);
  });

  test('FakeSpeechGenerator returns audio bytes', () async {
    final stages = _stages();
    final fake = FakeSpeechGenerator();
    final result = await fake.generateSpeech(
      const SpeechRequest(prompt: 'hello'),
      onProgress: (p) => stages.add(p.stage),
    );
    expect(result.kind, MediaKind.speech);
    expect(result.mimeType, 'audio/mpeg');
    expect(fake.lastRequest!.prompt, 'hello');
    expect(stages.last, GenerationStage.done);
  });

  test('FakeSoundEffectGenerator returns audio bytes', () async {
    final stages = _stages();
    final fake = FakeSoundEffectGenerator();
    final result = await fake.generateSoundEffect(
      const SoundEffectRequest(prompt: 'boom'),
      onProgress: (p) => stages.add(p.stage),
    );
    expect(result.kind, MediaKind.soundEffect);
    expect(result.mimeType, 'audio/mpeg');
    expect(fake.lastRequest, isNotNull);
    expect(stages.last, GenerationStage.done);
  });

  test('FakeMusicGenerator returns audio bytes', () async {
    final stages = _stages();
    final fake = FakeMusicGenerator();
    final result = await fake.generateMusic(
      const MusicRequest(prompt: 'jazz'),
      onProgress: (p) => stages.add(p.stage),
    );
    expect(result.kind, MediaKind.music);
    expect(result.mimeType, 'audio/mpeg');
    expect(fake.lastRequest, isNotNull);
    expect(stages.last, GenerationStage.done);
  });

  group('FakeTextGenerator', () {
    test('returns the fixture text as UTF-8 bytes', () async {
      final stages = _stages();
      final fake = FakeTextGenerator(text: 'hi there');
      final result = await fake.generateText(
        const TextRequest(prompt: 'q'),
        onProgress: (p) => stages.add(p.stage),
      );
      expect(result.kind, MediaKind.text);
      expect(result.mimeType, 'text/plain');
      expect(result.text, 'hi there');
      expect(utf8.decode(result.bytes), 'hi there');
      expect(stages.last, GenerationStage.done);
    });
  });
}
