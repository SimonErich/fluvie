import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/errors/fluvie_render_exception.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/rendering/clip_audio_staging.dart';

import 'fakes/fake_media_resolver.dart';

void main() {
  group('clipAudioSourceFor', () {
    test('maps file / asset / network clips to the matching AudioSource', () {
      expect(
        clipAudioSourceFor(const MediaSource.file('/v.mp4')),
        const AudioSource.file('/v.mp4'),
      );
      expect(
        clipAudioSourceFor(const MediaSource.asset('v.mp4')),
        const AudioSource.asset('v.mp4'),
      );
      final url = Uri.parse('https://x/v.mp4');
      expect(clipAudioSourceFor(MediaSource.network(url)), AudioSource.network(url));
    });

    test('rejects a memory clip (no file to extract audio from)', () {
      expect(
        () => clipAudioSourceFor(MediaSource.memory(Uint8List(0))),
        throwsA(isA<FluvieRenderException>()),
      );
    });
  });

  test('stageClipAudio materializes the clip and builds a delayed, trimmed node', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(const {}, audioPaths: {audioSource: src.path});
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 30,
          windowFrames: 60,
          audio: const ClipAudio.included(volume: 0.5),
          trim: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 90,
    );

    expect(nodes, hasLength(1));
    final node = nodes.single;
    expect(node.delayMs, 1000); // 30 frames at 30 fps
    expect(node.trimEndSeconds, 2.0); // 60-frame window at 30 fps
    expect(node.volume, 0.5);
    expect(File('${sandbox.path}/${node.name}').existsSync(), isTrue);
  });
}
