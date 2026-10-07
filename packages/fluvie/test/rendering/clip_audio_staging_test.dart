import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluvie/src/core/audio/audio_source.dart';
import 'package:fluvie/src/core/media/clip_audio.dart';
import 'package:fluvie/src/core/media/media_source.dart';
import 'package:fluvie/src/core/time.dart';
import 'package:fluvie/src/core/time_extensions.dart';
import 'package:fluvie/src/core/time_range.dart';
import 'package:fluvie/src/elements/runtime/clip_frame_planner.dart';
import 'package:fluvie/src/elements/runtime/clip_resampler.dart';
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

    test('maps a memory clip to a memory audio source sharing its bytes', () {
      final bytes = Uint8List.fromList(const [9, 9, 9]);
      final source = clipAudioSourceFor(MediaSource.memory(bytes, debugLabel: 'cam.mp4'));
      expect(source, isA<MemoryAudioSource>());
      final memory = source as MemoryAudioSource;
      expect(memory.bytes, same(bytes));
      expect(memory.debugLabel, 'cam.mp4');
      // Content-hashed: identical bytes re-imported share one staged name.
      expect(memory.cacheKey, AudioSource.memory(Uint8List.fromList(const [9, 9, 9])).cacheKey);
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
          speed: 1,
          sourceTimeMap: null,
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
    expect(node.trimStartSeconds, 0.0); // no trim: the source plays from its head
    expect(node.trimEndSeconds, 2.0); // 60-frame window at 30 fps
    expect(node.volume, 0.5);
    expect(File('${sandbox.path}/${node.name}').existsSync(), isTrue);
  });

  test('stageClipAudio starts a trimmed clip where its picture starts', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      // A 10 s source at 30 fps, so `2.seconds.to(7.seconds)` is frames 60..210.
      metadata: {clip: const (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 90, // a 3 s window inside the 5 s trim
          audio: const ClipAudio.included(),
          trim: 2.seconds.to(7.seconds),
          speed: 1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 90,
    );

    final node = nodes.single;
    expect(node.trimStartSeconds, 2.0);
    expect(node.trimEndSeconds, 5.0);
    // `atrim`'s bounds are absolute source times, not a length: the audio has
    // to enter the file where the picture does, or the clip plays out of sync.
    expect(
      node.filterChain(inputIndex: 0, label: 'a0'),
      contains('atrim=start=2:end=5'),
    );
  });

  test('stageClipAudio ends a trimmed clip at the trim, not past it', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: const (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 300, // a 10 s window around a 5 s trim
          audio: const ClipAudio.included(),
          trim: 2.seconds.to(7.seconds),
          speed: 1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 300,
    );

    expect(nodes.single.trimEndSeconds, 7.0);
  });

  test('a faster clip spends more source time per composition second', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: const (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 90, // 3 composition seconds
          audio: const ClipAudio.included(),
          trim: 2.seconds.to(9.seconds),
          speed: 2,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 90,
    );

    final node = nodes.single;
    expect(node.trimStartSeconds, 2.0);
    // 3 composition seconds at 2x consume 6 source seconds, so 2..8.
    expect(node.trimEndSeconds, 8.0);
    expect(node.filterChain(inputIndex: 0, label: 'a0'), contains('atempo=2'));
  });

  test("a rate outside atempo's range is chained rather than clipped", () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: const (fps: 30.0, frameCount: 900, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 30,
          audio: const ClipAudio.included(),
          trim: null,
          speed: 4,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 30,
    );

    // atempo takes 0.5..2.0, so 4x is two stages, not a silently clipped one.
    expect(nodes.single.filterChain(inputIndex: 0, label: 'a0'), contains('atempo=2,atempo=2'));
  });

  test('a clip fade-out ends when the clip does, not when the file does', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: const (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          // Starts 2s in and plays for 3s, so it ends at 5s on the mix
          // timeline; a half-second ramp out therefore begins at 4.5s.
          startFrame: 60,
          windowFrames: 90,
          audio: const ClipAudio.included(fadeOut: Time.frames(15)),
          trim: null,
          speed: 1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 150,
    );

    final node = nodes.single;
    expect(node.fadeOutSeconds, 0.5);
    expect(node.fadeOutStartSeconds, 4.5);
    expect(
      node.filterChain(inputIndex: 0, label: 'a0'),
      contains('afade=t=out:st=4.5:d=0.5'),
    );
  });

  test('a reversed clip contributes no audio track at all', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: const (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true)},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 30,
          audio: const ClipAudio.included(),
          trim: null,
          speed: -1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 30,
    );

    // Nothing in this graph reverses a stream, so shipping the forward audio
    // under backwards picture would be worse than shipping none.
    expect(nodes, isEmpty);
  });

  test('a staged clip enters its audio on the same source frame its picture does', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = File('${dir.path}/clip.mp4')..writeAsBytesSync(const [1, 2, 3]);
    const clip = MediaSource.asset('clip.mp4');
    final audioSource = clipAudioSourceFor(clip);
    const meta = (fps: 30.0, frameCount: 300, width: 16, height: 9, hasAudio: true);
    final resolver = FakeMediaResolver(
      const {},
      audioPaths: {audioSource: src.path},
      metadata: {clip: meta},
    );
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();
    final trim = 2.seconds.to(7.seconds);

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 45,
          windowFrames: 90,
          audio: const ClipAudio.included(),
          trim: trim,
          speed: 1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 180,
    );

    // The one assertion that would have caught the desync: whatever source
    // frame the painter reads on the window's first composition frame is the
    // source time the mix opens the audio at.
    final bounds = resolveClipTrimBounds(trim, meta);
    final firstPainted = resampleClipFrame(
      compFrame: 45,
      windowStart: 45,
      compFps: 30,
      srcFps: meta.fps,
      trimStartFrames: bounds.start,
      trimEndFrames: bounds.end,
    );
    expect(nodes.single.trimStartSeconds, firstPainted / meta.fps);
  });

  test('stageClipAudio stages a memory clip from its materialized temp file', () async {
    final dir = Directory.systemTemp.createTempSync('fluvie_clip_audio_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = Uint8List.fromList(const [4, 5, 6]);
    final src = File('${dir.path}/staged')..writeAsBytesSync(bytes);
    final clip = MediaSource.memory(bytes, debugLabel: 'media/cam.mp4');
    final audioSource = clipAudioSourceFor(clip);
    final resolver = FakeMediaResolver(const {}, audioPaths: {audioSource: src.path});
    await resolver.preResolveAudio([audioSource]);
    final sandbox = Directory('${dir.path}/sandbox')..createSync();

    final nodes = await stageClipAudio(
      plans: [
        (
          source: clip,
          startFrame: 0,
          windowFrames: 30,
          audio: const ClipAudio.included(),
          trim: null,
          speed: 1,
          sourceTimeMap: null,
        ),
      ],
      resolver: resolver,
      sandbox: sandbox,
      fps: 30,
      totalFrames: 30,
    );

    final node = nodes.single;
    // The staged name carries the content hash, matching the web staging.
    expect(node.name, 'clip_audio_0_${audioSource.cacheKey}');
    expect(File('${sandbox.path}/${node.name}').readAsBytesSync(), bytes);
  });
}
